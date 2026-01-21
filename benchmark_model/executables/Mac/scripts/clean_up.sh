#!/bin/bash

# Define the folder prefix and range
FOLDER_PREFIX="a"
START=1
END=16

# Loop through each folder and delete it
for i in $(seq $START $END); do
  FOLDER="${FOLDER_PREFIX}${i}"
  
  # Check if the folder exists
  if [ -d "$FOLDER" ]; then
    echo "Deleting folder: $FOLDER"
    rm -rf "$FOLDER"  # Remove the folder and its contents
  else
    echo "Folder '$FOLDER' does not exist. Skipping."
  fi
done

echo "Cleanup complete. All folders deleted."
