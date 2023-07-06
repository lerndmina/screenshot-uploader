#!/bin/bash

echo "Starting script"

# Enable extended globbing patterns
shopt -s extglob

# Check if all necessary commands are installed
if ! command -v inotifywait &>/dev/null || ! command -v timeout &>/dev/null || ! command -v kdialog &>/dev/null || ! command -v curl &>/dev/null || ! command -v echo &>/dev/null || ! command -v mv &>/dev/null || ! command -v xsel &>/dev/null &>/dev/null; then
  echo "One or more necessary commands could not be found"
  echo "Trying to install the following commands:"
  echo "inotifywait, timeout, kdialog, curl, echo, mv, xsel"
  echo ""

  # Check if apt is available
  if command -v apt &>/dev/null; then
    echo "Using apt to install dependencies"
    sudo apt install inotify-tools coreutils kdialog curl xsel
  # Check if pacman is available
  elif command -v pacman &>/dev/null; then
    echo "Using pacman to install dependencies"
    sudo pacman -S inotify-tools coreutils kdialog curl xsel
  else
    echo "Could not find a package manager to install dependencies"
    exit 1
  fi
fi

echo ""
echo "Dependency check passed, checking config file"

config_file="screenshot-upload.conf"

# Check if config file does not exist
if ! test -f "$config_file"; then
  echo ""
  echo "Config file does not exist, creating default config file..."
  # Get username for default config file
  USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')

  # Create default config file with comments
  echo "# Configuration file for screenshot upload script" >$config_file
  echo "" >>$config_file
  echo "# Source directory for screenshots must be an absolute path" >>$config_file
  echo "source_d=\"/home/$USERNAME/Pictures/Screenshots/\"" >>$config_file
  echo "# Destination directory for archived screenshots must be an absolute path" >>$config_file
  echo "move_loc=\"/home/$USERNAME/Pictures/Screenshot-Archive/\"" >>$config_file
  echo "# Base URL for uploaded screenshots" >>$config_file
  echo "base_url=\"https://example.com/cdn/\"" >>$config_file
  echo "# Upload script file name this must be at the url above" >>$config_file
  echo "upload_file=\"upload.php\"" >>$config_file
  echo "# Password for uploading screenshots" >>$config_file
  echo "password=\"PASSWORD\"" >>$config_file

  echo ""
  echo "Please edit the config file to your liking, and then run the script again"

  exit 1
else
  echo ""
  echo "Config file exists, checking if all variables are set"
  # Check if all variables exist in config file
  if ! grep -q "^source_d=" $config_file ||
    ! grep -q "^move_loc=" $config_file ||
    ! grep -q "^base_url=" $config_file ||
    ! grep -q "^upload_file=" $config_file ||
    ! grep -q "^password=" $config_file; then
    echo ""
    echo "One or more variables are missing from the config file"
    echo "please add them and try again or delete the config file to generate a new one"
    echo ""
    exit 1
  fi
fi

# Load variables from config file
source $config_file

# Check if source directory exists
if [ ! -d "$source_d" ]; then
  echo "Source directory does not exist"
  exit 1
fi

# Check if move location exists
if [ ! -d "$move_loc" ]; then
  echo "Move location does not exist"
  exit 1
fi

# Check if upload file exists
if [ -z "$upload_file" ]; then
  echo "Upload file does not exist in config file"
  exit 1
fi

# Check if base URL is valid
if ! curl --output /dev/null --silent --head --fail "$base_url/$upload_file"; then
  echo "Base URL is not valid or $upload_file does not exist at that endpoint"
  exit 1
fi

# Check if password exists
if [ -z "$password" ]; then
  echo "Password does not exist in config file"
  exit 1
else
  # Check if user has already responded to prompt
  if ! $dont_test_password; then
    echo ""
    echo "Skipping password test, remove dont_test_password from config file to test password again"
  else
    # Prompt user to test password
    if kdialog --yesno "Do you want to test the password?" --title "Screenshot Uploader"; then
      # Upload test image to check if password is correct
      RESPONSE=$(curl -s \
        -F "password=$password" \
        -F "image=@$source_d/test.png" \
        $base_url/$upload_file)

      # Check if response contains error-401
      if echo "$RESPONSE" | grep -q "error-401"; then
        kdialog --title "Screenshot Uploader Error" --error "Response contains an error: Invalid Password, please check your config file"
        exit 1
      fi

      # Check if response contains error
      if echo "$RESPONSE" | grep -q "error" && ! echo "$RESPONSE" | grep -q "error-401"; then
        echo ""
        echo "Response contains an error: $RESPONSE"
        kdialog --title "Screenshot Uploader Error" --error "Response contains an error: $RESPONSE"
        exit 1
      fi
    fi
    # Store user's response in config file
    echo -e "\n" >>$config_file
    echo "dont_test_password=true" >>$config_file
  fi
fi

echo ""
echo "All tests passed, starting listener"
echo ""

# Upload test image to check if password is correct

rm -r $source_d/!(*test).png >/dev/null 2>&1

inotifywait -m -q -e close_write "$source_d" |
  while read -r path action file; do
    if [[ "$file" =~ .*png$ ]]; then
      if timeout 5s kdialog --yesno "Do you want to upload that screenshot?" --title "Screenshot upload"; then
        RESPONSE=$(curl -s \
          -F "password=$password" \
          -F "image=@$source_d$file" \
          $base_url/$upload_file)
        URL=("$base_url/$RESPONSE") # Concatinates the code with the url
        echo "Uploaded \"$URL\""
        mv $source_d$file $move_loc
        echo -n "$URL" | xsel --clipboard
        kdialog --passivepopup "Screenshot uploaded to $URL" 3 --title "Screenshot upload"
      else
        mv $source_d$file $move_loc
      fi
    fi
  done
