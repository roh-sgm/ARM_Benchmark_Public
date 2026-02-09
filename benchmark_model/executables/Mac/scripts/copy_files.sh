#!/bin/bash

# Define the source folder
SOURCE_FOLDER="files"
START=1
END=16

# Check if the source folder exists
if [ ! -d "$SOURCE_FOLDER" ]; then
  echo "Source folder '$SOURCE_FOLDER' does not exist."
  exit 1
fi

# Loop to create folders a1 through a16 and copy the contents
for i in $(seq "$START" "$END"); do
  DEST_FOLDER="a$i"
  
  # Create the destination folder if it doesn't exist
  if [ ! -d "$DEST_FOLDER" ]; then
    mkdir "$DEST_FOLDER"
    echo "Created folder: $DEST_FOLDER"
  fi
  
  # Copy the contents of the source folder into the destination folder
  cp -R "$SOURCE_FOLDER"/* "$DEST_FOLDER"
  echo "Copied contents of '$SOURCE_FOLDER' to '$DEST_FOLDER'"
done

echo "All files copied successfully."
