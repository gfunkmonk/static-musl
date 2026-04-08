#!/usr/bin/env bash

############################################################################################################################
#    ___      _ _   __  __        ___      _ _    _   _      _____ _         _   _                                         #
#   / __|__ _| | | |  \/  |_ _   | _ )_  _(_| |__| | (_)    |_   _| |_  __ _| |_( )___  _ __ _  _   _ _  __ _ _ __  ___    #
#  | (__/ _` | | | | |\/| | '__  | _ | || | | / _` |_ _       | | | ' \/ _` |  _|/(_-< | '  | || | | ' \/ _` | '  \/ -_)_  #
#   \___\__,_|_|_| |_|  |_|_|(_) |___/\_,_|_|_\__,_( (_)      |_| |_||_\__,_|\__| /__/ |_|_|_\_, | |_||_\__,_|_|_|_\___(_) #
#   _____ _         _                              |/          _        _      __  __        |__/     _ _    _             #
#  |_   _| |_  __ _| |_   _ _  __ _ _ __  ___   __ _ __ _ __ _(_)_ _   (_)___ |  \/  |_ _   | _ )_  _(_| |__| |            #
#    | | | ' \/ _` |  _| | ' \/ _` | '  \/ -_) / _` / _` / _` | | ' \  | (_-< | |\/| | '__  | _ | || | | / _` |_           #
#    |_| |_||_\__,_|\__| |_||_\__,_|_|_|_\___| \__,_\__, \__,_|_|_||_| |_/__/ |_|  |_|_|(_) |___/\_,_|_|_\__,_(_)          #
############################################################################################################################

# Default flags
RESUME=false
DRY_RUN=false
SELECTED_TOOLS=""
PARALLEL_JOBS=1
CHECKSUM=false
CLEAN_DIST=false
USE_CROSS=false  # New Flag
CLANG_CROSS=false

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
  echo -e "  ${SKY}--tui${NC}              Launch interactive TUI for selection."
  echo -e ""
  echo -e "  ${SKY}--parallel <n>${NC}     Number of concurrent build jobs."
  echo -e "  ${SKY}--resume${NC}           Skip tools that already have a binary in ${NC}dist/."
  echo -e "  ${SKY}--list-tools${NC}       Show all available build scripts and their last version."
  echo -e "  ${SKY}--tool <name(s)>${NC}   Build specific tool(s). Supports comma-separated list."
  echo -e "                       Example: ${NEONPINK}--tool curl,wget,nano${NC}"
  echo -e "  ${SKY}--dry-run${NC}          Show which scripts would be executed without running them."
  echo -e "  ${SKY}--arch <arch>${NC}      Target architecture (x86_64, aarch64, armv7, armhf, x86)."
  echo -e "                       Overrides ARCH environment variable."
  echo -e "  ${SKY}--cross${NC}            Download and use prebuilt musl-cross toolchains for non-native builds."
  echo -e "  ${SKY}--clang-cross${NC}      Same as above but downloads clang toolchain instead of gcc."
  echo -e ""
  echo -e "  ${SKY}--checksum${NC}         Generate SHA256 checksums for all files in dist/ after building."
  echo -e "  ${SKY}--clean${NC}            Remove dist/*.tar.xz before building."
  echo -e "  ${SKY}--help${NC}             Display this help message and exit."
  echo -e ""
  exit 0
}

setup_cross_toolchain() {
    local arch="${ARCH:-x86_64}"
    [ "$arch" == "x86_64" ] && return 0

    local tc_name=""
    case "$arch" in
        aarch64) tc_name="aarch64-unknown-linux-musl" ;;
        armv7)   tc_name="armv7-unknown-linux-musleabihf" ;;
        armhf)   tc_name="arm-unknown-linux-musleabihf" ;;
        x86|i686) tc_name="i686-unknown-linux-musl" ;;
        *) return 0 ;;
    esac

    local toolchain_dir="$(pwd)/toolchains"
    local tc_path="${toolchain_dir}/${tc_name}"

    if [ ! -d "$tc_path" ]; then
        echo -e "${NEONBLUE}= Downloading $tc_name toolchain...${NC}"
        mkdir -p "$toolchain_dir"
        if [ "$CLANG_CROSS" = false ]; then
          curl -L "https://github.com/gfunkmonk/musl-cross/releases/download/prevalence/${tc_name}.tar.xz" | tar -xJ -C "$toolchain_dir"
        else
          curl -L "https://github.com/gfunkmonk/clang-cross/releases/download/magazine/${tc_name}.tar.xz" | tar -xJ -C "$toolchain_dir"
        fi
    fi

    # Export variables for sub-scripts to inherit
    export CROSS_BIN_PATH="$tc_path"
    local prefix=$(ls "${tc_path}/bin"/*-gcc | head -n1 | xargs basename | sed 's/gcc//')
    export CROSS_PREFIX="$prefix"
}

run_tui() {
  if ! command -v dialog >/dev/null 2>&1; then
    echo -e "${NEONRED}Error: 'dialog' is not installed.${NC}"
    echo -e "Install it with: ${SKY}sudo apt install dialog${NC} or ${SKY}apk add dialog${NC}"
    exit 1
  fi

  # Select Architecture
  ARCH_CHOICE=$(dialog --clear --title "Architecture Selection" \
    --radiolist "Select target architecture:" 15 50 5 \
    "x86_64"  "AMD64 / Standard PC" ON \
    "aarch64" "ARM64 / v8" OFF \
    "armv7"   "ARMv7 / Raspberry Pi" OFF \
    "armhf"   "ARM Hard Float" OFF \
    "x86"     "i386 / 32-bit" OFF \
    2>&1 >/dev/tty)

  [ -z "$ARCH_CHOICE" ] && exit 0
  export ARCH="$ARCH_CHOICE"

  # Select Tools
  TOOL_LIST=()
  for script in *-static-musl.sh; do
    [ -f "$script" ] || continue
    name=$(echo "$script" | sed 's/-static-musl//; s/\.sh//')
    TOOL_LIST+=("$name" "" OFF)
  done

  SELECTED_TOOLS=$(dialog --clear --title "Tool Selection" \
    --checklist "Space to select tools to build:" 20 60 12 \
    "${TOOL_LIST[@]}" 2>&1 >/dev/tty | tr ' ' ',')

  JOBS=$(dialog --title "Parallel Jobs" --inputbox \
  "Number of concurrent build jobs:" 15 50 1 \
  2>&1 >/dev/tty)
  PARALLEL_JOBS=$JOBS

  # Select Build Options
  OPTIONS=$(dialog --separate-output --title "Options" \
    --checklist "Build Flags:" 12 50 4 \
    "resume"   "Skip existing" OFF \
    "checksum" "Generate SHA256" OFF \
    "clean"    "Clean dist/" OFF \
    "cross"    "Cross-compile" OFF \
    2>&1 >/dev/tty)

  [[ $OPTIONS == *"resume"* ]] && RESUME=true
  [[ $OPTIONS == *"checksum"* ]] && CHECKSUM=true
  [[ $OPTIONS == *"clean"* ]] && CLEAN_DIST=true
  [[ $OPTIONS == *"cross"* ]] && USE_CROSS=true

}

# Change to the repository root
cd "$(dirname "$0")/.."

# Handle arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      ;;
    --tui)
      run_tui
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
    --cross)
      USE_CROSS=true
      ;;
    --clang-cross)
      USE_CROSS=true
      CLANG_CROSS=true
      export CLANG_CROSS=true
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

# Initialize Cross-Toolchain if requested
if [ "$USE_CROSS" = true ]; then
    setup_cross_toolchain
fi

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
echo -e "--- Starting file execution loop (${NEONGREEN}$PARALLEL_JOBS${NC} jobs) ---" | tee -a "$LOG_FILE"
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

        # --- THE FIX: Bridge the Toolchain into the Chroot ---
        if [ "$USE_CROSS" = true ] && [ -n "${CROSS_BIN_PATH:-}" ]; then
            # We wait until the sub-script creates the directory, or we pre-create it
            # Since common.sh handles mounting, we just pass the info
            export CROSS_COMPILE_HOST_PATH="$CROSS_BIN_PATH"
        fi

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

# Print the names of failed tools
if [ "$failure_count" -gt 0 ]; then
  echo -e "\n${NEONRED}=== Failed tools: ===${NC}" | tee -a "$LOG_FILE"
  for f in "$STATUS_DIR"/*; do
    base=$(basename "$f")
    [[ "$base" == *.0 ]] && continue
    tool="${base%.*}"
    echo -e "  ${HIGHLIGHTER}✗ ${tool}${NC}  (log: logs/builds/${tool}.txt)" | tee -a "$LOG_FILE"
  done
fi

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
