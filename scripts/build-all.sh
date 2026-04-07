#!/usr/bin/env bash

# Default flags
RESUME=false
DRY_RUN=false
SELECTED_TOOLS=""
PARALLEL_JOBS=1
CHECKSUM=false
CLEAN_DIST=false

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
  echo -e "  ${SKY}--parallel <n>${NC}     Number of concurrent build jobs."
  echo -e "  ${SKY}--resume${NC}           Skip tools that already have a binary in ${NC}dist/."
  echo -e "  ${SKY}--list-tools${NC}       Show all available build scripts and their last version."
  echo -e "  ${SKY}--tool <name(s)>${NC}   Build specific tool(s). Supports comma-separated list."
  echo -e "                       Example: ${NEONPINK}--tool curl,wget,nano${NC}"
  echo -e "  ${SKY}--dry-run${NC}          Show which scripts would be executed without running them."
  echo -e "  ${SKY}--arch <arch>${NC}      Target architecture (x86_64, aarch64, armv7, armhf, x86)."
  echo -e "                       Overrides ARCH environment variable."
  echo -e "  ${SKY}--checksum${NC}         Generate SHA256 checksums for all files in dist/ after building."
  echo -e "  ${SKY}--clean${NC}            Remove dist/*.tar.xz before building."
  echo -e "  ${SKY}--help${NC}             Display this help message and exit."
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
    --parallel)
      PARALLEL_JOBS="${2:?--parallel requires a number}"
      shift
      ;;
    --arch)
      export ARCH="$2"
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    --checksum)
      CHECKSUM=true
      ;;
    --clean)
      CLEAN_DIST=true
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
STATUS_DIR=$(mktemp -d)

# Cleanup on exit
cleanup() {
  rm -rf "$STATUS_DIR"
  # Kill background jobs if interrupted
  [ "$(jobs -pr)" ] && jobs -pr | xargs -r kill 2>/dev/null
}
trap cleanup EXIT

mkdir -p "$LOG_DIR/builds"
if [ "$RESUME" = false ]; then
    rm -f "${LOG_DIR}"/builds/*.txt
    > "$LOG_FILE"
fi

if [ "$CLEAN_DIST" = true ]; then
    echo -e "${ORANGE}= Cleaning dist/*.tar.xz ...${NC}" | tee -a "$LOG_FILE"
    rm -f dist/*.tar.xz
fi

success_count=0
failure_count=0
current_jobs=0
echo -e "--- Starting file execution loop (${NEONBLUE}$PARALLEL_JOBS${NC} jobs) ---" | tee -a "$LOG_FILE"
if [ "$RESUME" = true ]; then
    echo -e "\n--- RESUMING BUILD AT $(date) ---" >> "$LOG_FILE"
fi
[ "$RESUME" = true ] && echo -e "${NEONPURPLE}Resume mode active: Skipping existing binaries.${NC}" | tee -a "$LOG_FILE"

for file in *-static-musl.sh; do
    [ -f "$file" ] || continue
    bin_name=$(echo "$file" | sed 's/-static-musl//; s/\.sh//')

    if [[ -n "$SELECTED_TOOLS" ]]; then
        if [[ ! ",$SELECTED_TOOLS," =~ ",$bin_name," ]]; then continue; fi
    fi

    if [ "$RESUME" = true ]; then
        arch_pattern="${ARCH:+-${ARCH}}"
        if compgen -G "dist/${bin_name}-*${arch_pattern}.tar.xz" > /dev/null 2>&1; then
            echo -e "${NEONPINK}Skipping ${SKY}$file${NC} (Binary exists in dist/)" | tee -a "$LOG_FILE"
            touch "$STATUS_DIR/${bin_name}.0"
            continue
        fi
    fi

    if [ "$DRY_RUN" = true ]; then
        echo -e "${HIGHLIGHTER}[DRY-RUN] ${BWHITE}Would build: ${NEONGREEN}${file}${NC}"
        touch "$STATUS_DIR/${bin_name}.0"
        continue
    fi

    # Parallel Job Control
    (
        # Prevent chroot collision by giving each job a unique directory name
        export CHROOTDIR="chroot-${ARCH:-native}-${bin_name}"

        echo -e "${LAGOON}Started: ${LEMON}$file${BWHITE} (Log: ${bin_name}.txt)${NC}" | tee -a "$LOG_FILE"
        chmod +x "$file"

        # Execute and capture exit status
        ./"$file" > "${LOG_DIR}/builds/${bin_name}.txt" 2>&1
        exit_status=$?

        if [ $exit_status -eq 0 ]; then
            echo -e "${JUNEBUD}SUCCESS: ${VIOLET}$file${NC}" | tee -a "$LOG_FILE"
        else
            echo -e " ${NEONRED}FAILURE: ${LEMON}$file ${BWHITE}(Check ${bin_name}.txt)${NC}" | tee -a "$LOG_FILE"
        fi

        # Write exit status to a file so the parent can count it
        echo "$exit_status" > "$STATUS_DIR/${bin_name}.$exit_status"
    ) &

    current_jobs=$((current_jobs + 1))

    # Wait for the next available slot if the parallel limit is reached
    if [[ $current_jobs -ge $PARALLEL_JOBS ]]; then
        wait -n
        current_jobs=$((current_jobs - 1))
    fi
done

# Wait for all remaining background jobs to finish
wait

# Process results from the status directory
success_count=$(ls "$STATUS_DIR" 2>/dev/null | grep -c "\.0$" || echo 0)
failure_count=$(ls "$STATUS_DIR" 2>/dev/null | grep -v "\.0$" | wc -l || echo 0)

echo "-----------------------------------" | tee -a "$LOG_FILE"
echo -e "\n${MINT}--- Execution Summary ---${NC}" | tee -a "$LOG_FILE"
echo -e "${HOTPINK}Total files processed: $((success_count + failure_count))${NC}" | tee -a "$LOG_FILE"
echo -e "${SKY}Successful executions: $success_count${NC}" | tee -a "$LOG_FILE"
echo -e "${NEONRED}Failed executions: $failure_count${NC}" | tee -a "$LOG_FILE"

echo -e "${VIOLET}Results logged to $LOG_FILE${NC}"

if [ "$CHECKSUM" = true ]; then
    CHECKSUM_FILE="dist/SHA256SUMS"
    echo -e "${NEONBLUE}= Generating SHA256 checksums for dist/...${NC}" | tee -a "$LOG_FILE"
    if compgen -G "dist/*.tar.xz" > /dev/null 2>&1; then
        ( cd dist && sha256sum ./*.tar.xz | sed 's|\./||' ) > "$CHECKSUM_FILE"
        echo -e "${NEONGREEN}= Checksums written to ${CHECKSUM_FILE}${NC}" | tee -a "$LOG_FILE"
    else
        echo -e "${ORANGE}= No dist/*.tar.xz files found for checksum generation.${NC}" | tee -a "$LOG_FILE"
    fi
fi
