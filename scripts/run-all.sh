#!/bin/bash

# Iterate over all files in the current directory
for file in *-static-musl.sh; do
  # Check if the item is a regular file (and not a directory)
  if [ -f "$file" ]; then
    echo "Running $file"
    # Execute the file
    "./$file"
    # You can add error handling here if a file fails to run
  fi
done