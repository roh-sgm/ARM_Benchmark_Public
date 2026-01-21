#!/bin/bash

# Define the folder prefix
FOLDER_PREFIX="a"
START=1
END=16

# Loop through each folder
for i in $(seq $START $END); do
  FOLDER="${FOLDER_PREFIX}${i}"
  
  # Check if the folder exists
  if [ -d "$FOLDER" ]; then
    echo "Opening terminal in folder: $FOLDER"

    # Open a new terminal window and run the script inside the folder
    osascript <<EOF
tell application "Terminal"
  do script "cd \"$(pwd)/$FOLDER\" && ./run.sh"
end tell
EOF

  else
    echo "Folder '$FOLDER' does not exist. Skipping."
  fi
done

echo "All terminal windows opened and ./run.sh executed."
