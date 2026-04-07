#!/usr/bin/env bash

# Default: do not resume unless flag is passed
RESUME=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resume)
      RESUME=true
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

# Change to the repository root
cd "$(dirname "$0")/.."

LOG_DIR=${PWD}/logs/
mkdir -p "$LOG_DIR"/builds/

# Clear logs only if NOT in resume mode
if [ "$RESUME" = false ]; then
    # Use -f to prevent errors if the directory is already empty
    rm -f "${LOG_DIR}"/*.txt
fi

LOG_FILE="${LOG_DIR}/build_log.txt"
# Note: > "$LOG_FILE" below will still truncate the main build_log.txt, 
# which is usually what you want so the summary doesn't double up.
# If you want the main log to append during resume, change > to >>
[ "$RESUME" = true ] && exec_redir=">>" || exec_redir=">"

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
HIGHLIGHTER="\033[38;2;248;255;15m"
BWHITE="\033[1;37m"
NC="\033[0m"

success_count=0
failure_count=0
[ "$RESUME" = false ] && > "$LOG_FILE"

echo "--- Starting file execution loop ---" | tee -a "$LOG_FILE"
[ "$RESUME" = true ] && echo -e "${CHARTREUSE}Resume mode active: Skipping existing binaries.${NC}" | tee -a "$LOG_FILE"

for file in *-static-musl.sh; do
    if [ -f "$file" ]; then
        # 1. Determine the binary name from the script name
        # e.g., curl-static-musl.sh -> curl
        bin_name=$(echo "$file" | sed 's/-static-musl//; s/\.sh//')

        if [ "$DRY_RUN" = true ]; then
            echo -e "${HIGHLIGHTER}[DRY-RUN] ${BWHITE}Would build: ${CHARTREUSE}${file}${NC}"
            success_count=$((success_count + 1))
            continue
        fi

        # 2. RESUME LOGIC: If flag is set AND binary exists, skip it
        if [ "$RESUME" = true ] && compgen -G "dist/${bin_name}-*" > /dev/null 2>&1; then
            echo -e "${SKY}Skipping ${LEMON}$file${NC} (Binary ${CHARTREUSE}${bin_name}${NC} already exists in dist/)" | tee -a "$LOG_FILE"
            success_count=$((success_count + 1))
            continue
        fi

        echo -e "${LAGOON}Processing file: ${LEMON}$file${NC}" | tee -a "$LOG_FILE"
        chmod +x "$file"

        # Execute and capture log
        ./"$file" 2>&1 | tee -a "${LOG_DIR}/builds/${bin_name}.txt"
        exit_status=${PIPESTATUS[0]}

        if [ $exit_status -eq 0 ]; then
            echo -e "${JUNEBUD}SUCCESS: ${VIOLET}$file${NC}" | tee -a "$LOG_FILE"
            success_count=$((success_count + 1))
        else
            echo -e " ${TOMATO}FAILURE: ${LEMON}$file${NC}" | tee -a "$LOG_FILE"
            failure_count=$((failure_count + 1))
            # Stop the loop on failure so you can fix it and resume
            echo -e "${ORANGE}Stopping build. Fix error and run with --resume to continue.${NC}"
            break
        fi
        echo "-----------------------------------" | tee -a "$LOG_FILE"
    fi
done

echo -e "${MINT}--- Execution Summary ---${NC}" | tee -a "$LOG_FILE"
echo -e "${LAGOON}Total files processed: $((success_count + failure_count))${NC}" | tee -a "$LOG_FILE"
echo -e "${PEACH}Successful executions: $success_count${NC}" | tee -a "$LOG_FILE"
echo -e "${CHARTREUSE}Failed executions: $failure_count${NC}" | tee -a "$LOG_FILE"

echo -e "${VIOLET}Results logged to $LOG_FILE${NC}"

