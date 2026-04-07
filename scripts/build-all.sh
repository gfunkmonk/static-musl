#!/usr/bin/env bash

# Default flags
RESUME=false
DRY_RUN=false
SELECTED_TOOLS=""

JUNEBUD="\033[38;2;189;218;87m"
SKY="\033[38;2;135;206;250m"
VIOLET="\033[38;2;207;159;255m"
MINT="\033[38;2;152;255;152m"
ORANGE="\033[38;2;255;165;0m"
LEMON="\033[38;2;255;244;79m"
PEACH="\033[38;2;246;161;146m"
LAGOON="\033[38;2;142;235;236m"
HIGHLIGHTER="\033[38;2;248;255;15m"
BWHITE="\033[1;37m"
NEONPINK="\033[38;2;255;19;240m"
HOTPINK="\033[38;2;255;105;180m"
NEONRED="\033[38;2;255;49;49m"
NEONGREEN="\033[38;2;57;255;20m"
NEONBLUE="\033[38;2;4;218;255m"
NEONPURPLE="\033[38;2;225;8;255m"
NC="\033[0m"

usage() {
  echo -e "${BWHITE}Usage: ${NC}./$(basename "$0") [OPTIONS]"
  echo -e ""
  echo -e "${BWHITE}Options:${NC}"
  echo -e "  ${SKY}--tool <name(s)>${NC}    Build specific tool(s). Supports comma-separated list."
  echo -e "                       Example: ${NEONPINK}--tool curl,wget,nano${NC}"
  echo -e "  ${SKY}--resume${NC}           Skip tools that already have a binary in ${NC}dist/."
  echo -e "                       Appends to existing logs instead of overwriting."
  echo -e "  ${SKY}--list-tools${NC}       Show all available build scripts and their last version."
  echo -e "  ${SKY}--dry-run${NC}          Show which scripts would be executed without running them."
  echo -e "  ${SKY}--help${NC}             Display this help message and exit."
  echo -e ""
  echo -e "${BWHITE}Environment Variables:${NC}"
  echo -e "  ${NEONGREEN}ARCH${NC}               Target architecture (e.g., x86_64, aarch64)."
  echo -e ""
  exit 0
}

# Change to the repository root
cd "$(dirname "$0")/.."

# Handle arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      ;;
    --resume)
      RESUME=true
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    --tool)
      SELECTED_TOOLS="$2"
      shift
      ;;
    --list-tools)
      echo -e "${BWHITE}Available Tools & Last Built Versions:${NC}"
      echo "------------------------------------------------"
      for script in *-static-musl.sh; do
        b_name=$(echo "$script" | sed 's/-static-musl//; s/\.sh//')
        # Find latest version in dist/ (e.g., curl-8.6.0-x86_64.tar.xz)
        latest=$(ls dist/${b_name}-*-*.tar.xz 2>/dev/null | tail -n 1 | sed "s|dist/||; s|${b_name}-||; s|-${ARCH:-.*}.tar.xz||")
        printf "${PEACH}%-15s${NC} %s\n" "$b_name" "${latest:-[No build found]}"
      done
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

LOG_DIR="${PWD}/logs"
LOG_FILE="${LOG_DIR}/build_log.txt"

mkdir -p "$LOG_DIR/builds"
if [ "$RESUME" = false ]; then
    rm -f "${LOG_DIR}"/builds/*.txt
    > "$LOG_FILE"
fi

success_count=0
failure_count=0
echo "--- Starting file execution loop ---" | tee -a "$LOG_FILE"
if [ "$RESUME" = true ]; then
    echo -e "\n--- RESUMING BUILD AT $(date) ---" >> "$LOG_FILE"
fi
[ "$RESUME" = true ] && echo -e "${NEONPURPLE}Resume mode active: Skipping existing binaries.${NC}" | tee -a "$LOG_FILE"

for file in *-static-musl.sh; do
    [ -f "$file" ] || continue
    bin_name=$(echo "$file" | sed 's/-static-musl//; s/\.sh//')
    if [[ -n "$SELECTED_TOOLS" ]]; then
        if [[ ! ",$SELECTED_TOOLS," =~ ",$bin_name," ]]; then
            continue
        fi
    fi

    if [ "$DRY_RUN" = true ]; then
        echo -e "${HIGHLIGHTER}[DRY-RUN] ${BWHITE}Would build: ${NEONGREEN}${file}${NC}"
        success_count=$((success_count + 1))
        continue
    fi

    if [ "$RESUME" = true ]; then
        arch_pattern="${ARCH:+-${ARCH}}"
        if compgen -G "dist/${bin_name}-*${arch_pattern}.tar.xz" > /dev/null 2>&1; then
            echo -e "${NEONPINK}Skipping ${SKY}$file${NC} (Binary exists in dist/)" | tee -a "$LOG_FILE"
            success_count=$((success_count + 1))
            continue
        fi
    fi

    echo -e "${LAGOON}Processing file: ${LEMON}$file${NC}" | tee -a "$LOG_FILE"
    chmod +x "$file"

    ./"$file" 2>&1 | tee -a "${LOG_DIR}/builds/${bin_name}.txt"
    exit_status=${PIPESTATUS[0]}
    if [ $exit_status -eq 0 ]; then
        echo -e "${JUNEBUD}SUCCESS: ${VIOLET}$file${NC}" | tee -a "$LOG_FILE"
        success_count=$((success_count + 1))
    else
        echo -e " ${NEONRED}FAILURE: ${LEMON}$file${NC}" | tee -a "$LOG_FILE"
        failure_count=$((failure_count + 1))
        echo -e "${ORANGE}Stopping build. Fix error and run with --resume to continue.${NC}"
        break
    fi
    echo "-----------------------------------" | tee -a "$LOG_FILE"
done

echo -e "${MINT}--- Execution Summary ---${NC}" | tee -a "$LOG_FILE"
echo -e "${HOTPINK}Total files processed: $((success_count + failure_count))${NC}" | tee -a "$LOG_FILE"
echo -e "${SKY}Successful executions: $success_count${NC}" | tee -a "$LOG_FILE"
echo -e "${NEONRED}Failed executions: $failure_count${NC}" | tee -a "$LOG_FILE"

echo -e "${VIOLET}Results logged to $LOG_FILE${NC}"
