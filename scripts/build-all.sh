#!/bin/bash

# Change to the repository root so *-static-musl.sh scripts and log output
# are located relative to the repo regardless of where this script is invoked from.
cd "$(dirname "$0")/.."

LOG_DIR=${PWD}/logs

if [ ! -d "$LOG_DIR" ]; then
  echo "Directory $LOG_DIR does not exist. Creating it now..."
  mkdir -p "$LOG_DIR"
fi

LOG_FILE="${LOG_DIR}/build_log_$(date +%Y%m%d_%H%M%S).txt"

JUNEBUD="\033[38;2;189;218;87m"
SKY="\033[38;2;135;206;250m"
VIOLET="\033[38;2;143;0;255m"
MINT="\033[38;2;152;255;152m"
ORANGE="\033[38;2;255;165;0m"
LEMON="\033[38;2;255;244;79m"
TOMATO="\033[38;2;255;99;71m"
CHARTREUSE="\033[38;2;127;255;0m"
PEACH="\033[38;2;246;161;146m"
LAGOON="\033[38;2;142;235;236m"
NC="\033[0m"

# Counters for success and failure
success_count=0
failure_count=0

# Clear log file from previous runs
> "$LOG_FILE"

echo "--- Starting file execution loop ---" | tee -a "$LOG_FILE"

# Loop through all files in the specified directory
for file in *-static-musl.sh; do
    # Check if the item is a regular file
    if [ -f "$file" ]; then
        echo -e "${LAGOON}Processing file: ${LEMON}$file${NC}" | tee -a "$LOG_FILE"
        
        # Make the file executable if it is not already
        chmod +x "$file"

        # Execute the file and capture the exit status
        ./"$file"
        exit_status=$?

        # Check the exit status (0 usually means success, anything else is failure)
        if [ $exit_status -eq 0 ]; then
            echo -e "${JUNEBUD}SUCCESS: ${VIOLET}$file finished with exit status${SKY} $exit_status${NC}" | tee -a "$LOG_FILE"
            ((success_count++))
        else
            echo -e " ${TOMATO}FAILURE: ${LEMON}$file finished with exit status ${CHARTREUSE}$exit_status${NC}" | tee -a "$LOG_FILE"
            ((failure_count++))
        fi
        echo "-----------------------------------" | tee -a "$LOG_FILE"
    fi
done

echo -e "${MINT}--- Execution Summary ---${NC}" | tee -a "$LOG_FILE"
echo -e "${LAGOON}Total files processed: $((success_count + failure_count))${NC}" | tee -a "$LOG_FILE"
echo -e "${PEACH}Successful executions: $success_count${NC}" | tee -a "$LOG_FILE"
echo -e "${CHARTREUSE}Failed executions: $failure_count${NC}" | tee -a "$LOG_FILE"

echo -e "${VIOLET}Results logged to $LOG_FILE${NC}"