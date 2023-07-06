# Screenshot Uploader
A bash screenshot uploader companion to https://github.com/aerouk/imageserve/ for systems that can't use Sharex
This script monitors a directory for new PNG screenshots and uploads them to a specified server using cURL. It also moves the uploaded screenshots to a different directory and copies the URL to the clipboard.

## Prerequisites

The following commands must be installed on your system:

- inotifywait
- timeout
- kdialog
- curl
- echo
- mv
- xsel

If any of these commands are missing, the script will try to install them using the package manager `apt` or `pacman`.

## Configuration

The script reads its configuration from a file named `screenshot-upload.conf`. If this file does not exist, the script will create a default configuration file with comments.

The following variables must be set in the configuration file:

- `source_d`: the absolute path of the directory to monitor for new screenshots
- `move_loc`: the absolute path of the directory to move uploaded screenshots to
- `base_url`: the base URL of the server to upload screenshots to
- `upload_file`: the name of the upload script file on the server
- `password`: the password to use for uploading screenshots

## Usage

To start the script, run the following command:

```shellscript
./upload.sh
```
The script will start monitoring the `source_d` directory for new PNG screenshots. When a new screenshot is detected, the script will prompt the user to upload it. If the user confirms, the script will upload the screenshot to the server using cURL and move it to the `move_loc` directory. The script will also copy the URL of the uploaded screenshot to the clipboard and display a notification.

## Testing the Password

The `upload.sh` script includes a test to check if the password specified in the configuration file is correct. This test is performed by uploading a test image to the server and checking the response.

The test is performed automatically the first time the script is started. If the password is incorrect, the test will fail and the script will exit with an error message.

If the password is correct, the server should respond with a URL of the uploaded image. If the password is incorrect, the server should respond with an error message.

Note that the test image `test.png` must be present in the same directory as the `upload.sh` script for the test to work.

## License
This script is licensed under the MIT License.
