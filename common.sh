#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
CONF_FILE="${SCRIPT_DIR}"/config.sh
[[ -f "${CONF_FILE}" ]] && source "${CONF_FILE}"

##### Colors ################
BWHITE="\033[1;37m"
ORANGE="\033[38;2;255;165;0m"
LEMON="\033[38;2;255;244;79m"
TAWNY="\033[38;2;204;78;0m"
HELIOTROPE="\033[38;2;223;115;255m"
VIOLET="\033[38;2;143;0;255m"
MINT="\033[38;2;152;255;152m"
AQUA="\033[38;2;18;254;202m"
TOMATO="\033[38;2;255;99;71m"
PEACH="\033[38;2;246;161;146m"
LAGOON="\033[38;2;142;235;236m"
HOTPINK="\033[38;2;255;105;180m"
LIME="\033[38;2;204;255;0m"
OCHRE="\033[38;2;204;119;34m"
SLATE="\033[38;2;109;129;150m"
SKY="\033[38;2;135;206;250m"
JUNEBUD="\033[38;2;189;218;87m"
NAVAJO="\033[38;2;255;222;173m"
BOYSENBERRY="\033[38;2;135;50;96m"
CORAL="\033[38;2;240;128;128m"
CAMEL="\033[38;2;193;154;107m"
INDIGO="\033[38;2;111;0;255m"
CHARTREUSE="\033[38;2;127;255;0m"
PURPLE_BLUE="\033[38;2;147;130;255m"
REBECCA="\033[38;2;102;51;153m"
TEAL="\033[38;2;0;128;128m"
TURQUOISE="\033[38;2;64;224;208m"
BLOOD="\033[38;2;102;6;6m"
UGLY="\033[38;2;122;115;115m"
CARIBBEAN="\033[38;2;0;204;153m"
CRIMSON="\033[38;2;220;20;60m"
CANARY="\033[38;2;255;255;153m"
MISTYROSE="\033[38;2;255;226;223m"
MAUVE="\033[38;2;224;175;255m"
MOSS="\033[38;2;138;154;91m"
COOLGRAY="\033[38;2;140;146;172m"
NC="\033[0m"

######################
# Setup Validation   #
######################
# Validate required environment
for var in ALPINE_VERSION ALPINE_MAJOR_MINOR CHROOTDIR; do
  if [ -z "${!var:-}" ]; then
    echo -e "${CRIMSON}= ERROR: Required variable $var is not set${NC}" >&2
    exit 1
  fi
done

# Validate disk space (need at least 2GB free)
required_space_kb=$((2 * 1024 * 1024))
available_space_kb=$(df . -k | tail -1 | awk '{print $4}')
if [ "$available_space_kb" -lt "$required_space_kb" ]; then
  echo -e "${CRIMSON}= ERROR: Insufficient disk space${NC}" >&2
  echo -e "${CRIMSON}  Required: 2GB, Available: $((available_space_kb / 1024))MB${NC}" >&2
  exit 1
fi

##############################################
# normalize ARCH names                       #
# Map various CPU architecture names         #
# to canonical values used by Alpine Linux   #
# x86-64/amd64 → x86_64  (Intel/AMD 64-bit)  #
# i386/i486/i586/i686 → x86  (Intel 32-bit)  #
# arm64/armv8 → aarch64  (ARM 64-bit)        #
# armv7* → armv7  (ARM 32-bit with NEON)     #
# armv6/arm → armhf  (ARM 32-bit hard-float) #
##############################################
ARCH=${ARCH:-$(uname -m)}
case "${ARCH}" in
  x86-64|amd64) ARCH="x86_64" ;;
  i*86)         ARCH="x86" ;;
  arm64|armv8)  ARCH="aarch64" ;;
  armv7*)       ARCH="armv7" ;;
  armv6|arm)    ARCH="armhf" ;;
  *)    echo -e "${MAUVE}= ARCH '${ARCH}' not in normalization map, using as-is${NC}" ;;
esac

####################
#   Setup tools    #
####################
for tool in jq curl upx; do
  bundled="tools/${tool}/${tool}-${ARCH}"
  if [[ -x "$bundled" ]] && "$bundled" --version &>/dev/null; then
    declare "${tool^^}=$bundled"
  elif command -v "$tool" &>/dev/null; then
    echo -e "${LIME}= bundled $tool not usable, falling back to system $tool${NC}" >&2
    declare "${tool^^}=$tool"
  else
    echo -e "${BLOOD}= ERROR: no $tool available (checked $bundled and PATH)${NC}" >&2
    exit 1
  fi
done

########################################################
# setup_arch: resolve QEMU_ARCH & ARCH_FLAGS from ARCH #
########################################################
setup_arch() {
  case "${ARCH}" in
    x86_64)
      QEMU_ARCH=""
      ARCH_FLAGS="-march=x86-64 -mtune=generic"
      ;;
    x86)
      QEMU_ARCH="i386"
      ARCH_FLAGS="-march=pentium-m -mtune=generic"
      ;;
    aarch64)
      QEMU_ARCH="aarch64"
      ARCH_FLAGS="-march=armv8-a"
      ;;
    armv7)
      QEMU_ARCH="arm"
      ARCH_FLAGS="-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard -marm"
      ;;
    armhf)
      QEMU_ARCH="arm"
      ARCH_FLAGS="-march=armv6kz -mfloat-abi=hard -mfpu=vfp -marm"
      ;;
    *)
      echo -e "${LAGOON}Unknown architecture: ${HOTPINK}${ARCH}${NC}" >&2
      exit 1
      ;;
  esac
  # ALPINE_TARBALL is the Alpine minirootfs filename (distinct from the build source tarball)
  ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_MAJOR_MINOR}/releases/${ARCH}/alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz"
  ALPINE_TARBALL="${ALPINE_URL##*/}"
}

#########################################
# Get latest release or tag from Github #
#########################################
get_version() {
  local type="$1" repo="$2" filter="$3" fallback="$4" version
  local endpoint="releases/latest" default_f=".tag_name"

  [[ "$type" == "tag" ]] && { endpoint="tags"; default_f=".[0].name"; }

  # This specific line fixes the "api.github.com{repo}" error
  local url="https://api.github.com/repos/${repo}/${endpoint}"

  version=$("${CURL}" -fsSL --connect-timeout 10 --max-time 30 \
    ${GITHUB_TOKEN:+-H "Authorization: Bearer ${GITHUB_TOKEN}"} \
    "$url" | "${JQ}" -r "${filter:-$default_f} // empty" 2>/dev/null)

  if [[ -n "$version" && "$version" != "null" ]]; then
    echo "$version"
  else
    local name="${repo##*/}"
    echo -e "${TAWNY}= GitHub API unavailable, falling back to $name $fallback${NC}" >&2
    echo "$fallback"
  fi
}

##############################################################
# Helper to fetch latest version from cgit/gitweb interfaces #
##############################################################
get_git_version() {
    local url="$1"
    local pattern="$2"
    local strip_prefix="$3"
    local fallback="$4"

    # 1. Fetch tags
    # 2. Extract matches
    # 3. Use 'sed' to temporarily turn underscores into dots for sorting
    # 4. Sort by version (sort -V)
    # 5. Take the last one (the highest version)
    # 6. Finally, strip the requested prefix
    local version=$("${CURL}" -sL --connect-timeout 5 --max-time 15 "$url" | \
        grep -oE "$pattern" | \
        sed 's/_/./g' | \
        sort -V | \
        tail -n 1 | \
        sed "s|^${strip_prefix//_/.}||")

    if [ -z "$version" ]; then
        echo "$fallback"
    else
        # Normalise separator — turns e.g. ".P1" → "p1" (needed for OpenSSH tags
        # like "V_10_1_P1"; for other tools this substitution is a no-op).
        echo "$version" | sed 's/\.[Pp]/p/'
    fi
}

get_gitlab_version() {
    local project_path="$1" # e.g., "gnuwget/wget2"
    local fallback="$2"

    # API returns tags ordered by date by default
    local version=$("${CURL}" -s "https://gitlab.com/api/v4/projects/${project_path//\//%2F}/repository/tags" | \
        grep -oP '"name":"v?\K[0-9]+\.[0-9]+\.[0-9]+' | \
        head -n 1)

    if [ -z "$version" ]; then
        echo "$fallback"
    else
        echo "$version"
    fi
}

###############################################################
# unmount_chroot: safely unmount all bind mounts in chroot    #
# Called from the EXIT trap (setup_cleanup) and package_output#
###############################################################
unmount_chroot() {
  local max_attempts=3
  local attempt=0

  while [ $attempt -lt $max_attempts ]; do
    if ! grep -qF "$(pwd)/${CHROOTDIR}" /proc/mounts 2>/dev/null; then
      return 0  # Successfully unmounted
    fi

    if command -v findmnt >/dev/null 2>&1; then
      sudo findmnt --list --noheadings --output TARGET | grep -F "$(pwd)/${CHROOTDIR}" | tac | xargs -r sudo umount -nfR 2>/dev/null || true
    else
      grep -F "$(pwd)/${CHROOTDIR}" /proc/mounts | cut -f2 -d" " | sort -r | xargs -r sudo umount -nfR 2>/dev/null || true
    fi

    sleep 2
    (( ++attempt ))
  done

  # Final check
  if grep -qF "$(pwd)/${CHROOTDIR}" /proc/mounts; then
    if [ "${GITHUB_ACTIONS:-}" == "true" ] || [ "${CI:-}" == "true" ]; then
      echo -e "${TOMATO}CI Environment detected. Forcing lazy unmount...${NC}"
      grep -F "$(pwd)/${CHROOTDIR}" /proc/mounts | cut -f2 -d" " | sort -r | xargs -r sudo umount -l 2>/dev/null || true
    else
      read -p "DANGER - Do you want to lazy unmount? (y/n): " yn
      case $yn in
        [yY] ) grep -F "$(pwd)/${CHROOTDIR}" /proc/mounts | cut -f2 -d" " | sort -r | xargs -r sudo umount -l 2>/dev/null || true;;
        [nN] ) echo -e "${TOMATO}ERROR: Failed to unmount all filesystems in ${CHROOTDIR} after ${max_attempts} attempts${NC}" >&2; exit;;
        * ) echo "Invalid response"; exit 1;;
      esac
    fi
  fi
}

###############################################################
# setup_cleanup: register unmount trap for chroot bind mounts #
###############################################################
setup_cleanup() {
  trap unmount_chroot EXIT
}

#####################################################################
# install_host_deps: install required packages on the Ubuntu runner #
#####################################################################
install_host_deps() {
  echo -e "${AQUA}= install dependencies${NC}"
  local DEBIAN_DEPS=(binutils)
  [ -n "${QEMU_ARCH}" ] && DEBIAN_DEPS+=(qemu-user-static)
  sudo apt-get update -qy > /dev/null && sudo apt-get install -qy --no-install-recommends "${DEBIAN_DEPS[@]}"
}

####################################################################
# download_source LABEL VERSION TARBALL mirror1 [mirror2 ...]      #
# Downloads TARBALL from the first mirror that succeeds.           #
# Skips the download if it exists and validates file is not empty. #
# Uses a .tmp file to avoid leaving corrupt partial downloads.     #
####################################################################
download_source() {
  local label="$1" version="$2" tarball="$3"
  shift 3
  if [ ! -d distfiles/ ]; then
    echo -e "${INDIGO}distfiles dir does not exist. Creating it now.${NC}"
    mkdir -p distfiles/
  fi
  if [ -f "distfiles/${tarball}" ]; then
    echo -e "${SLATE}= ${label}-${version}: distfiles/${tarball} already cached, skipping download${NC}"
    # Verify cached file is not empty
    if [ ! -s "distfiles/${tarball}" ]; then
      echo -e "${CRIMSON}= ERROR: Cached file is empty: distfiles/${tarball}${NC}" >&2
      exit 1
    fi
    return 0
  fi
  echo -e "${AQUA}= downloading ${label}-${version} tarball${NC}"
  local tmp_file="distfiles/${tarball}.tmp"
  # PID suffix avoids collisions when multiple builds run concurrently in the same workspace
  local error_log="distfiles/${tarball}.$$.err"
  local downloaded=false
  local mirror_count=0
  local total_mirrors=$#

  for mirror in "$@"; do
    mirror_count=$((mirror_count + 1))
    echo -e "${TAWNY}= trying mirror [${mirror_count}/${total_mirrors}]: ${mirror}${NC}"

    # Capture curl output (both stdout redirect and stderr to error log)
    if "${CURL}" -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 120 \
        -o "${tmp_file}" "${mirror}" 2>"${error_log}"; then
      # Verify downloaded file is not empty
      if [ ! -s "${tmp_file}" ]; then
        echo -e "${LEMON}= failed: downloaded file is empty, trying next mirror${NC}"
        rm -f "${tmp_file}"
        continue
      fi
      mv "${tmp_file}" "distfiles/${tarball}"
      echo -e "${MINT}= successfully downloaded from: ${mirror}${NC}"
      rm -f "${error_log}"
      downloaded=true
      break
    else
      local exit_code=$?
      echo -e "${LEMON}= download failed: ${mirror}${NC}"

      # Parse and display the actual error
      if [ -s "${error_log}" ]; then
        local error_msg=$(head -n 1 "${error_log}" | sed 's/^curl: //')
        echo -e "${TOMATO}  └─ Error: ${error_msg}${NC}" >&2
      else
        # Map common curl exit codes to human-readable messages
        case ${exit_code} in
          6)  echo -e "${CORAL}  └─ Error: Could not resolve host${NC}" >&2 ;;
          7)  echo -e "${HOTPINK}  └─ Error: Failed to connect${NC}" >&2 ;;
          22) echo -e "${ORANGE}  └─ Error: HTTP error (404, 403, etc.)${NC}" >&2 ;;
          28) echo -e "${CHARTREUSE}  └─ Error: Timeout${NC}" >&2 ;;
          35) echo -e "${TURQUOISE}  └─ Error: SSL connection error${NC}" >&2 ;;
          *)  echo -e "${LIME}  └─ Error: curl exit code ${exit_code}${NC}" >&2 ;;
        esac
      fi
      rm -f "${tmp_file}" "${error_log}"
    fi
  done
  if [ "${downloaded}" = false ]; then
    echo -e "${CRIMSON}= ERROR: all ${total_mirrors} mirror(s) failed for ${tarball}${NC}" >&2
    echo -e "${CRIMSON}= Please check your network connection or try again later${NC}" >&2
    exit 1
  fi
}

#####################################################
# setup_alpine_chroot TARBALL                       #
# Downloads Alpine rootfs, extracts it, and copies  #
# resolv.conf + source tarball inside.              #
#####################################################
setup_alpine_chroot() {
  local PREBAKED_IMAGE="alpine-base-${ARCH}.tar.gz"
  local tarball="$1"
  if [ -d "./${CHROOTDIR}" ] && [ "${KEEP_CHROOT}" = "false" ]; then
    unmount_chroot
    if grep -qF "$(pwd)/${CHROOTDIR}" /proc/mounts; then
      echo -e "${TOMATO}ERROR: Mounts still active in ${CHROOTDIR}. Deletion ${BLOOD}BLOCKED!${NC}" >&2
      exit 1
    fi
    echo -e "${CORAL}= chroot dir exist! Removing it now.${NC}"
    rm -fr "./${CHROOTDIR}"
  fi
  if [ -f "minirootfs/${PREBAKED_IMAGE}" ]; then
      echo -e "${CARIBBEAN}= Found pre-baked image: ${PREBAKED_IMAGE}. Extracting...${NC}"
      mkdir -p "./${CHROOTDIR}"
      sudo tar -xzf minirootfs/"${PREBAKED_IMAGE}" -C "./${CHROOTDIR}"
  else
      echo -e "${CORAL}= No pre-baked image found. Downloading official Alpine...${NC}"
      if [ ! -d minirootfs/ ]; then
        echo -e "${INDIGO}minirootfs dir does not exist. Creating it now.${NC}"
        mkdir -p minirootfs/
      fi
      if [ -f minirootfs/"${ALPINE_TARBALL}" ]; then
        echo -e "${SLATE}= Alpine rootfs ${ALPINE_TARBALL} already cached, skipping download${NC}"
        if [ ! -s minirootfs/"${ALPINE_TARBALL}" ]; then
          echo -e "${CRIMSON}= ERROR: Cached Alpine rootfs is empty: minirootfs/${ALPINE_TARBALL}${NC}" >&2
          exit 1
        fi
      else
        echo -e "${HELIOTROPE}= download alpine rootfs${NC}"
        "${CURL}" -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 120 \
        -o minirootfs/"${ALPINE_TARBALL}" "${ALPINE_URL}" \
        || { echo -e "${CRIMSON}= ERROR: failed to download Alpine rootfs${NC}" >&2; exit 1; }
      # Verify downloaded rootfs is not empty
      if [ ! -s minirootfs/"${ALPINE_TARBALL}" ]; then
        echo -e "${CRIMSON}= ERROR: Downloaded Alpine rootfs is empty${NC}" >&2
        exit 1
      fi
    fi
    echo -e "${SKY}= extract rootfs${NC}"
    mkdir -p "${CHROOTDIR}"
    tar xf minirootfs/"${ALPINE_TARBALL}" -C "${CHROOTDIR}"/
  fi
  echo -e "${TURQUOISE}= copy resolv.conf into chroot${NC}"
  cp /etc/resolv.conf "./${CHROOTDIR}/etc/" || \
    echo -e "${TAWNY}= WARNING: failed to copy resolv.conf — DNS may not work inside chroot${NC}"
  if [ "${tarball}" != "base-setup" ]; then
    echo -e "${PEACH}= copying ${tarball} into chroot${NC}"
    cp distfiles/"${tarball}" "./${CHROOTDIR}/${tarball}"
  fi
  # bundled tools
  echo -e "${NAVAJO}= install prebuilt tools${NC}"
  local src
  for prebuilt in 7zz upx uasm envx curl jq mold; do
    src="tools/${prebuilt}/${prebuilt}-${ARCH}"
    if [[ ! -f "$src" ]]; then
      echo -e "${CRIMSON}= ERROR: ${src} not found${NC}" >&2
      exit 1
    fi
    cp "$src" "./${CHROOTDIR}/usr/local/bin/${prebuilt}"
  done
}

#############################################################
# copy_patches TOOL patch1 [patch2 ...]                     #
# Copies named patch files from patches/TOOL/ into chroot.  #
#############################################################
copy_patches() {
  local tool="$1"; shift
  if [ ! -d "patches/${tool}" ]; then
    echo -e "${TOMATO}= ERROR: patches directory not found: patches/${tool}${NC}" >&2
    exit 1
  fi
  for patch in "$@"; do
    if [ ! -f "patches/${tool}/${patch}" ]; then
      echo -e "${TOMATO}= ERROR: patch file not found: patches/${tool}/${patch}${NC}" >&2
      exit 1
    fi
    cp "patches/${tool}/${patch}" "./${CHROOTDIR}/${patch}"
  done
}

############################################################
# setup_qemu: copy qemu into chroot for cross-arch builds  #
# Validates QEMU binary exists before copying.             #
############################################################
setup_qemu() {
  if [ -n "${QEMU_ARCH}" ]; then
    echo -e "${TURQUOISE}= setup QEMU for cross-arch builds${NC}"
    local qemu_bin
    if qemu_bin=$(command -v "qemu-${QEMU_ARCH}-static" 2>/dev/null); then
      echo -e "${SKY}= Found static QEMU: ${qemu_bin}${NC}"
      sudo mkdir -p "./${CHROOTDIR}/usr/bin/"
      sudo cp "${qemu_bin}" "./${CHROOTDIR}/usr/bin/"
    elif qemu_bin=$(command -v "qemu-${QEMU_ARCH}" 2>/dev/null); then
      echo -e "${CAMEL}= Found QEMU: ${qemu_bin} (copying as static)${NC}"
      sudo mkdir -p "./${CHROOTDIR}/usr/bin/"
      sudo cp "${qemu_bin}" "./${CHROOTDIR}/usr/bin/qemu-${QEMU_ARCH}-static"
    else
      echo -e "${CRIMSON}= ERROR: No QEMU binary found for ${QEMU_ARCH}${NC}" >&2
      echo -e "${PEACH}  Architecture: ${QEMU_ARCH}${NC}" >&2
      echo -e "${CANARY}  Current PATH: $PATH${NC}" >&2
      echo -e "${HELIOTROPE}= Install it with:${NC} ${TEAL}sudo apt-get install qemu-user-static or qemu-user-binfmt${NC}" >&2
      exit 1
    fi
  fi
}

##########################################################
# mount_chroot: bind-mount proc/dev/sys into the chroot  #
# Validates CCACHE_DIR exists before mounting.           #
##########################################################
mount_chroot() {
  echo -e "${VIOLET}= mount, bind and chroot into dir${NC}"
  sudo mount --rbind /dev "./${CHROOTDIR}/dev/"
  sudo mount --make-rslave "./${CHROOTDIR}/dev/"
  sudo mount --rbind /sys "./${CHROOTDIR}/sys/"
  sudo mount --make-rslave "./${CHROOTDIR}/sys/"
  sudo mount -t proc none "./${CHROOTDIR}/proc/"
  sudo mount -o bind /tmp "./${CHROOTDIR}/tmp/"
  sudo mount -t tmpfs -o nosuid,nodev,noexec,mode=755 none "./${CHROOTDIR}/run"
  # Mount ccache directories if CCACHE_DIR is set
  if [ -n "${CCACHE_DIR:-}" ]; then
    if [ ! -d "${CCACHE_DIR}" ]; then
      echo -e "${CRIMSON}= ERROR: CCACHE_DIR is set but directory does not exist: ${CCACHE_DIR}${NC}" >&2
      exit 1
    fi
    echo -e "${JUNEBUD}= bind mounting ccache directories${NC}"
    sudo mkdir -p "./${CHROOTDIR}/${CCACHE_CHROOT_DIR}"
    sudo mount --bind "${CCACHE_DIR}" "./${CHROOTDIR}/${CCACHE_CHROOT_DIR}"
    sudo mount --make-slave "./${CHROOTDIR}/${CCACHE_CHROOT_DIR}"
    sudo mkdir -p "./${CHROOTDIR}/${CCACHE_LOG_DIR}"
  fi
}

######################################################################################
# run_build_setup TOOL VERSION TARBALL [PATCH...] -- MIRROR [MIRROR...]              #
# Runs the full pre-chroot setup sequence. Patches and mirrors are separated by --.  #
# Usage (no patches):                                                                #
#   run_build_setup "curl" "8.19.0" "curl-8.19.0.tar.xz" -- "https://..." [...]     #
# Usage (with patches):                                                              #
#   run_build_setup "wget" "1.25.0" "wget.tar.gz" "wget.patch" -- "https://..." [...]#
######################################################################################
run_build_setup() {
  local tool="$1" version="$2" tarball="$3"
  shift 3
  local patches=()
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    patches+=("$1")
    shift
  done
  [[ $# -gt 0 && "$1" == "--" ]] && shift
  local mirrors=("$@")
  setup_arch
  setup_cleanup
  install_host_deps
  download_source "${tool}" "${version}" "${tarball}" "${mirrors[@]}"
  setup_alpine_chroot "${tarball}"
  [[ ${#patches[@]} -gt 0 ]] && copy_patches "${tool}" "${patches[@]}"
  setup_qemu
  mount_chroot
}

#########################################
# package_output TOOL BINARY            #
# Copies the built binary to dist/,     #
# creates an archive, and prints info.  #
#########################################
package_output() {
  local tool="$1" binary="$2"
  if [ ! -f "${binary}" ]; then
    echo -e "${CRIMSON}= ERROR: Binary not found: ${binary}${NC}" >&2
    exit 1
  fi
  local version_suffix=""
  [ -n "${PACKAGE_VERSION:-}" ] && version_suffix="-${PACKAGE_VERSION}"
  local filename="${tool}${version_suffix}-${ARCH}"
  install -D -m 755 "${binary}" "dist/${filename}"
  if command -v file >/dev/null 2>&1; then
    echo -e "\n"
    echo -e "${UGLY}= Verifying binary: ${filename}${NC}"
    if file "dist/${filename}" | grep -Ei "interpreter|dynamically linked" >/dev/null; then
        echo -e "${CRIMSON}!! WARNING: Binary is DYNAMICALLY linked !!${NC}"
        file "dist/${filename}"
    else
        echo -e "${LIME}= Verified: Binary is statically linked.${NC}"
    fi
  fi
  if [ "${USE_STRIP}" = "true" ]; then
      #echo -e "\n"
      echo -e "${CHARTREUSE}= Stripping ${filename}...${NC}"
      strip "dist/${filename}" 2>/dev/null || true
  fi
  if [ "${USE_UPX}" = "true" ]; then
      if [ -x "${UPX}" ]; then
          echo -e "${PURPLE_BLUE}= Compressing ${filename} with UPX...${NC}"
          ${UPX} ${UPX_FLAGS} "dist/${filename}" || true
      else
          echo -e "${TOMATO}! UPX binary not found at ${UPX}, skipping compression${NC}"
      fi
  fi
  if command -v file >/dev/null 2>&1; then
    echo -e "${ORANGE} File Info:  $(file "dist/${filename}" | cut -d: -f2-)${NC}"
  fi
  local temp_archive="dist/${filename}.tar.xz.tmp.$$"
  if ! tar -C dist -cJf "${temp_archive}" "${filename}"; then
    echo -e "${CRIMSON}= ERROR: Failed to create archive: ${temp_archive}${NC}" >&2
    rm -f "${temp_archive}"
    exit 1
  fi
  if [ ! -s "${temp_archive}" ]; then
    echo -e "${CRIMSON}= ERROR: Archive created but is empty: ${temp_archive}${NC}" >&2
    rm -f "${temp_archive}"
    exit 1
  fi
  mv "${temp_archive}" "dist/${filename}.tar.xz"
  echo -e "${JUNEBUD}= All done! Binary: dist/${filename} ($(du -sh "dist/${filename}" | cut -f1))${NC}"
  if [ "${KEEP_CHROOT}" = "false" ]; then
    if grep -qF "$(pwd)/${CHROOTDIR}" /proc/mounts; then
      unmount_chroot
    fi
    echo -e "${MISTYROSE}= Cleaning up chroot: ${CANARY}${CHROOTDIR}${NC}"
    sudo rm -rf "${CHROOTDIR}"
  else
    echo -e "${COOLGRAY}KEEP_CHROOT is true. ${MAUVE}Preserving: ${CHROOTDIR}${NC}"
  fi
}
