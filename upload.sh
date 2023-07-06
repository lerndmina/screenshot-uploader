#!/bin/bash

echo "Starting script"

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
  echo ""
  echo "Dependencies are now installed, waiting for screenshots to be taken"
fi

# Check if config file does not exist
if ! test -f "screenshot-upload.conf"; then
  echo "Config file does not exist, creating default config file..."
  # Get username for default config file
  USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')

  # Create default config file with comments
  echo "# Configuration file for screenshot upload script" >screenshot-upload.conf
  echo "" >>screenshot-upload.conf
  echo "# Source directory for screenshots must be an absolute path" >>screenshot-upload.conf
  echo "source_d=\"/home/$USERNAME/Pictures/Screenshots/\"" >>screenshot-upload.conf
  echo "# Destination directory for archived screenshots must be an absolute path" >>screenshot-upload.conf
  echo "move_loc=\"/home/$USERNAME/Pictures/Screenshot-Archive/\"" >>screenshot-upload.conf
  echo "# Base URL for uploaded screenshots" >>screenshot-upload.conf
  echo "base_url=\"https://example.com/cdn/\"" >>screenshot-upload.conf
  echo "# Upload script file name this must be at the url above" >>screenshot-upload.conf
  echo "upload_file=\"upload.php\"" >>screenshot-upload.conf
  echo "# Password for uploading screenshots" >>screenshot-upload.conf
  echo "password=\"PASSWORD\"" >>screenshot-upload.conf

  echo ""
  echo "Please edit the config file to your liking, and then run the script again"

  exit 1
else
  echo "Config file exists, checking if all variables are set"
  # Check if all variables exist in config file
  if ! grep -q "^source_d=" screenshot-upload.conf ||
    ! grep -q "^move_loc=" screenshot-upload.conf ||
    ! grep -q "^base_url=" screenshot-upload.conf ||
    ! grep -q "^upload_file=" screenshot-upload.conf ||
    ! grep -q "^password=" screenshot-upload.conf; then
    echo ""
    echo "One or more variables are missing from the config file"
    echo "please add them and try again or delete the config file to generate a new one"
    echo ""
    exit 1
  fi
fi

# Load variables from config file
source screenshot-upload.conf

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
fi

echo "All tests passed"

rm -r $source_d*.png >/dev/null 2>&1

inotifywait -m -q -e close_write "$source_d" |
  while read -r path action file; do
    if [[ "$file" =~ .*png$ ]]; then
      if timeout 5s kdialog --yesno "Do you want to upload that screenshot?" --title "Screenshot upload"; then
        echo curling = \"image=@$source_d$file\"
        RESPONSE=$(curl \
          -F "password=$password" \
          -F "image=@$source_d$file" \
          $base_url/$upload_file)
        echo Response = $RESPONSE
        URL=("$base_url/$RESPONSE") # Concatinates the code with the url
        echo $URL
        mv -v $source_d$file $move_loc
        echo -n "$URL" | xsel --clipboard
        kdialog --passivepopup "Screenshot uploaded to $URL" 3 --title "Screenshot upload"
      else
        mv -v $source_d$file $move_loc
      fi
    fi
  done
