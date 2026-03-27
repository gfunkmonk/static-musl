#!/bin/bash
# common.sh - Shared functions and variables for all *-static-musl.sh scripts.
# Source this file at the top of each build script: . "$(dirname "$0")/common.sh"

######### Variables ###########
ARCH=${ARCH:-$(uname -m)}
ALPINE_VERSION="3.23.3"
ALPINE_MAJOR_MINOR="${ALPINE_VERSION%.*}"

# Set directory name for the target chroot
CHROOTDIR=
CHROOTDIR=${CHROOTDIR:-potato}

# Compiler Flags
BCFLAGS="-Os -static -ffunction-sections -fdata-sections -fno-stack-protector"
EXTRA="-fshort-enums -fno-ident -fno-unwind-tables -fno-asynchronous-unwind-tables"
LTO="-flto=auto -ffat-lto-objects"

# Linker Flags
MOLD="-fuse-ld=mold"
BFD="-fuse-ld=bfd"
BLDFLAGS="-static -Wl,--gc-sections"

# Pkg-config
PKGCFG="pkg-config --static"

# CCACHE_CHROOT_DIR: path inside the chroot where ccache stores its cache.
# Set this to a host-mounted path (e.g. via CI cache) to persist ccache across
# builds.
# Defaults to /ccache (ephemeral, inside the chroot).
CCACHE_CHROOT_DIR="${CCACHE_CHROOT_DIR:-/ccache}"

# CCACHE gets its panties in a knot if the host has log_file defined and it doesn't
# exist in the chroot when the CCACHE directories are bind mounted. This was the best
# way I could find to get that string to make the directory.
CCACHE_LOG_DIR=$(ccache -p 2>/dev/null | grep log_file | cut -d "=" -f2 | rev | cut -d'/' -f2- | rev | sed 's/ //g') || true
CCACHE_LOG_DIR="${CCACHE_LOG_DIR:-/var/log/ccache}"

# Set KEEP_CHROOT=true via environment to preserve chroot after failed
# builds (for debugging)
KEEP_CHROOT="false"
KEEP_CHROOT=${KEEP_CHROOT:-false}

###### Bundled tools #########
JQ="tools/jq/jq-${ARCH}"
CURL="tools/curl/curl-${ARCH}"

##### Colors ################
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
NC="\033[0m"

########################
# normalize ARCH names #
########################
case "${ARCH}" in
  x86-64|amd64) ARCH="x86_64" ;;
  i*86)         ARCH="x86" ;;
  arm64|armv8)  ARCH="aarch64" ;;
  armv7*)       ARCH="armv7" ;;
  armv6|arm)    ARCH="armhf" ;;
  *)    echo -e "${REBECCA}${ARCH}${NC}" ;;
esac

####################
#   Setup tools    #
####################
if [[ -x "${JQ}" ]] && "${JQ}" --version >/dev/null 2>&1; then
  : # use bundled jq
elif command -v jq >/dev/null 2>&1; then
  echo -e "${LIME}= bundled jq not usable on this arch, falling back to system jq${NC}" >&2
  JQ="jq"
else
  echo -e "${BLOOD}= ERROR: no jq binary available (checked ${JQ} and PATH)${NC}" >&2
  exit 1
fi
if [[ -x "${CURL}" ]] && "${CURL}" --version >/dev/null 2>&1; then
  : # use bundled curl
elif command -v curl >/dev/null 2>&1; then
  echo -e "${LIME}= bundled curl not usable on this arch, falling back to system curl${NC}" >&2
  CURL="curl"
else
  echo -e "${BLOOD}= ERROR: no curl available (checked ${CURL} and PATH)${NC}" >&2
  exit 1
fi

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
  ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_MAJOR_MINOR}/releases/${ARCH}/alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz"
  TARBALL="${ALPINE_URL##*/}"
}
###########################################
# gh_latest_release REPO [JQ_FILTER]      #
# Fetches .tag_name from the GitHub       #
# releases/latest API, applies optional   #
# jq filter. Default:--> .tag_name as-is. #
###########################################
gh_latest_release() {
    local repo="$1" filter="${2:-.tag_name}"
    "${CURL}" -fsSL --connect-timeout 10 --max-time 30 \
        ${GITHUB_TOKEN:+-H "Authorization: Bearer ${GITHUB_TOKEN}"} \
        "https://api.github.com/repos/${repo}/releases/latest" \
        | "${JQ}" -r "${filter} // empty"
}

#####################################
# gh_latest_tag REPO [JQ_FILTER]    #
# Fetches the first entry from the  #
# GitHub tags API, applies optional #
# jq filter.                        #
#####################################
gh_latest_tag() {
    local repo="$1" filter="${2:-.[0].name}"
    "${CURL}" -fsSL --connect-timeout 10 --max-time 30 \
        ${GITHUB_TOKEN:+-H "Authorization: Bearer ${GITHUB_TOKEN}"} \
        "https://api.github.com/repos/${repo}/tags" \
        | "${JQ}" -r "${filter} // empty"
}

###############################################################
# setup_cleanup: register unmount trap for chroot bind mounts #
###############################################################
setup_cleanup() {
  cleanup() {
    echo -e "${CAMEL}Unmounting filesystems from chroot -- ${CHROOTDIR}${NC}"
    # Use -F for literal string matching (no regex), quote variables for safety
    grep -F "$(pwd)/${CHROOTDIR}" /proc/mounts | cut -f2 -d" " | sort -r | xargs -r sudo umount -nR || true
  }
  trap cleanup EXIT
}
#####################################################################
# install_host_deps: install required packages on the Ubuntu runner #
#####################################################################
install_host_deps() {
  echo -e "${AQUA}= install dependencies${NC}"
  local DEBIAN_DEPS=(binutils)
  [ -n "${QEMU_ARCH}" ] && DEBIAN_DEPS+=(qemu-user-static)
  sudo apt-get update -qy && sudo apt-get install -qy --no-install-recommends "${DEBIAN_DEPS[@]}"
}

####################################################################
# download_source LABEL VERSION TARBALL mirror1 [mirror2 ...]      #
# Downloads TARBALL from the first mirror that succeeds.           #
# Skips the download if it exists and validates file is not empty. #
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
      echo -e "${TOMATO}= ERROR: Cached file is empty: distfiles/${tarball}${NC}" >&2
      exit 1
    fi
    return 0
  fi
  echo -e "${AQUA}= downloading ${label}-${version} tarball${NC}"
  local downloaded=false
  for mirror in "$@"; do
    echo -e "${TAWNY}= trying mirror: ${mirror}${NC}"
    if "${CURL}" -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 120 \
        -o distfiles/"${tarball}" "${mirror}"; then
      # Verify downloaded file is not empty
      if [ ! -s distfiles/"${tarball}" ]; then
        echo -e "${LEMON}= downloaded file is empty, trying next mirror${NC}"
        rm -f distfiles/"${tarball}"
        continue
      fi
      echo -e "${MINT}= downloaded from: ${mirror}${NC}"
      downloaded=true
      break
    else
      echo -e "${LEMON}= failed: ${mirror}${NC}"
      rm -f distfiles/"${tarball}"
    fi
  done
  if [ "${downloaded}" = false ]; then
    echo -e "${TOMATO}= ERROR: all mirrors failed for ${tarball}${NC}" >&2
    exit 1
  fi
}
#####################################################
# setup_alpine_chroot TARBALL                       #
# Downloads Alpine rootfs, extracts it, and copies  #
# resolv.conf + source tarball inside.              #
#####################################################
setup_alpine_chroot() {
  local tarball="$1"
  if [ -d "./${CHROOTDIR}/" ] && [ "${KEEP_CHROOT}" = "false" ]; then
    grep -F "$(pwd)/${CHROOTDIR}" /proc/mounts | cut -f2 -d" " | sort -r | xargs -r sudo umount -nR || true
    echo -e "${CORAL}chroot dir exist! Removing it now.${NC}"
    rm -fr "./${CHROOTDIR}/"
  fi
  if [ ! -d minirootfs/ ]; then
    echo -e "${INDIGO}minirootfs dir does not exist. Creating it now.${NC}"
    mkdir -p minirootfs/
  fi
  if [ -f minirootfs/"${TARBALL}" ]; then
    echo -e "${SLATE}= Alpine rootfs ${TARBALL} already cached, skipping download${NC}"
  else
    echo -e "${HELIOTROPE}= download alpine rootfs${NC}"
    "${CURL}" -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 120 \
      -o minirootfs/"${TARBALL}" "${ALPINE_URL}" \
      || { echo -e "${TOMATO}= ERROR: failed to download Alpine rootfs${NC}" >&2; exit 1; }
    # Verify downloaded rootfs is not empty
    if [ ! -s minirootfs/"${TARBALL}" ]; then
      echo -e "${TOMATO}= ERROR: Downloaded Alpine rootfs is empty${NC}" >&2
      exit 1
    fi
  fi
  echo -e "${SKY}= extract rootfs${NC}"
  mkdir -p "${CHROOTDIR}"
  tar xf minirootfs/"${TARBALL}" -C "${CHROOTDIR}"/
  echo -e "${PEACH}= copy resolv.conf and ${tarball} into chroot${NC}"
  cp /etc/resolv.conf ./"${CHROOTDIR}"/etc/
  cp distfiles/"${tarball}" "./${CHROOTDIR}/${tarball}"
  # bundled tools
  for prebuilt in 7zz upx uasm envx curl jq mold; do
    src="tools/${prebuilt}/${prebuilt}-${ARCH}"
    if [[ ! -f "$src" ]]; then
      echo -e "${TOMATO}= ERROR: ${src} not found${NC}" >&2
      exit 1
    fi
    cp "$src" "./${CHROOTDIR}/usr/local/bin/${prebuilt}"
  done
}

#############################################################
# copy_patches patch1 [patch2 ...]                          #
# Copies named patch files from local into the chroot root. #
#############################################################
copy_patches() {
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
    echo -e "${OCHRE}= setup QEMU for cross-arch builds${NC}"
    if command -v qemu-"${QEMU_ARCH}"-static >/dev/null 2>&1; then
      local qemu_bin="/usr/bin/qemu-${QEMU_ARCH}-static"
      if [ ! -f "${qemu_bin}" ]; then
        echo -e "${TOMATO}= ERROR: QEMU binary not found: ${qemu_bin}${NC}" >&2
        echo -e "${HELIOTROPE}= Install it with:${NC} ${TEAL}sudo apt-get install qemu-user-static${NC}" >&2
        exit 1
      fi
      sudo mkdir -p "./${CHROOTDIR}/usr/bin/"
      sudo cp "${qemu_bin}" "./${CHROOTDIR}/usr/bin/"
    elif command -v qemu-"${QEMU_ARCH}" >/dev/null 2>&1; then
      local qemu_bin="/usr/bin/qemu-${QEMU_ARCH}"
    if [ ! -f "${qemu_bin}" ]; then
      echo -e "${TOMATO}= ERROR: QEMU binary not found: ${qemu_bin}${NC}" >&2
      echo -e "${HELIOTROPE}= Install it with:${NC} ${TEAL}sudo apt-get install qemu-user-binfmt${NC}" >&2
      exit 1
    fi
    sudo mkdir -p "./${CHROOTDIR}/usr/bin/"
    sudo cp "${qemu_bin}" "./${CHROOTDIR}/${qemu_bin}-static"
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
      echo -e "${TOMATO}= ERROR: CCACHE_DIR is set but directory does not exist: ${CCACHE_DIR}${NC}" >&2
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
# Usage: run_build_setup:
# "curl" "8.19.0" "curl-8.19.0.tar.xz" -- "https://..." [...] #
# Usage (with patches):                                                              #
# run_build_setup "wget" "1.25.0" "wget.tar.gz" "wget.patch" -- "https://..." [...]  #
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
  [[ ${#patches[@]} -gt 0 ]] && copy_patches "${patches[@]}"
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
    echo -e "${TOMATO}= ERROR: Binary not found: ${binary}${NC}" >&2
    exit 1
  fi
  local version_suffix=""
  [ -n "${PACKAGE_VERSION:-}" ] && version_suffix="-${PACKAGE_VERSION}"
  local filename="${tool}${version_suffix}-${ARCH}"
  mkdir -p dist
  cp "${binary}" "dist/${filename}"
  if command -v file >/dev/null 2>&1; then
    echo -e "${ORANGE} File Info:  $(file "dist/${filename}" | cut -d: -f2-)${NC}"
  fi
  tar -C dist -cJf "dist/${filename}.tar.xz" "${filename}"
  echo -e "${JUNEBUD}= All done! Binary: dist/${filename} ($(du -sh "dist/${filename}" | cut -f1))${NC}"
}
