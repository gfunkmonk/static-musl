#!/usr/bin/env bash

################################################################################
#     .oooooo.     .oooooo.   ooooo      ooo oooooooooooo ooooo   .oooooo.     #
#    d8P'  `Y8b   d8P'  `Y8b  `888b.     `8' `888'     `8 `888'  d8P'  `Y8b    #
#   888          888      888  8 `88b.    8   888          888  888            #
#   888          888      888  8   `88b.  8   888oooo8     888  888            #
#   888          888      888  8     `88b.8   888    "     888  888     ooooo  #
#   `88b    ooo  `88b    d88'  8       `888   888          888  `88.    .88'   #
#    `Y8bood8P'   `Y8bood8P'  o8o        `8  o888o        o888o  `Y8bood8P'    #
################################################################################

# Compiler Flags
BCFLAGS="-Os -static -ffunction-sections -fdata-sections -fno-stack-protector"
# -Os: optimize for size
# -static: force static linking
# -ffunction-sections -fdata-sections: enable dead code elimination
# -fno-stack-protector: reduce binary size (acceptable for static builds)
EXTRA="-fshort-enums -fno-ident -fno-unwind-tables -fno-asynchronous-unwind-tables"
# -fshort-enums: use smallest possible enum size
# -fno-ident: omit compiler identification strings
# -fno-unwind-tables: omit exception unwinding tables (size reduction)
LTO="-flto=auto -ffat-lto-objects"

# Linker Flags
MOLD="-fuse-ld=mold"
BFD="-fuse-ld=bfd"
LDSTRIP="-w -Wl,-s"
BLDFLAGS="-static -Wl,--gc-sections"

# Compilers
CC="${CC:-gcc}"
CXX="${CXX:-g++}"

# Pkg-config
PKGCFG="pkg-config --static"

######### Variables ###########
ALPINE_VERSION="3.23.3"
ALPINE_MAJOR_MINOR="${ALPINE_VERSION%.*}"

# Set directory name for the target chroot
: "${CHROOTDIR:=potato}"

# CCACHE_CHROOT_DIR: path inside the chroot where ccache stores its cache. Set this to a host-mounted path
# (e.g. via CI cache) to persist ccache across builds. Defaults to /ccache (ephemeral, inside the chroot).
: "${CCACHE_CHROOT_DIR:=/ccache}"

# Determine ccache's log_file directory so mount_chroot can pre-create it inside the chroot.
# We resolve the path carefully: if ccache is not installed or has no log_file configured,
# xargs dirname would receive empty input and return "." — so we guard against that.
_ccache_log_file=$(ccache -k log_file 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
[[ -n ${_ccache_log_file} && ${_ccache_log_file} != "null" ]] && CCACHE_LOG_DIR=$(dirname "${_ccache_log_file}")
unset _ccache_log_file
: "${CCACHE_LOG_DIR:=/var/log/ccache}"

# Preserve chroot after failed builds
# (for debugging)
: "${KEEP_CHROOT:=false}"

# Strip binaries
USE_STRIP="${USE_STRIP:-true}"

# Use UPX Compression
USE_UPX="${USE_UPX:-true}"
UPX_FLAGS="--lzma"

#################################
# Program versions for fallback #
#                               #
#################################
FALLBACK_SEVENZIP="v25.01-v1.5.7-R4"
FALLBACK_ARIA2C="1.37.0"
FALLBACK_AXEL="2.17.14"
FALLBACK_BASH="5.3"
FALLBACK_BSDTAR="3.8.6"
FALLBACK_CURL="8.19.0"
FALLBACK_DASH="0.5.13.2"
FALLBACK_DROPBEAR="2025.89"
FALLBACK_GAWK="5.4.0"
FALLBACK_HTOP="3.4.1"
FALLBACK_LESS="696"
FALLBACK_LFTP="4.9.3"
FALLBACK_NANO="8.7.1"
FALLBACK_NMAP="7.99"
FALLBACK_OKSH="7.8"
FALLBACK_OPENSSH="10.3p1"
FALLBACK_PIGZ="2.8"
FALLBACK_SCREEN="5.0.1"
FALLBACK_SED="4.9"
FALLBACK_SOCAT="1.8.1.1"
FALLBACK_TAR="1.3.5"
FALLBACK_TMUX="3.6a"
FALLBACK_TNFTP="20260211"
FALLBACK_UPX="5.1.1"
FALLBACK_VIM="9.2.0298"
FALLBACK_WGET="1.25.0"
FALLBACK_WGET2="2.2.1"
FALLBACK_XZ="5.8.3"
FALLBACK_ZSH="5.9"
FALLBACK_ZSTD="1.5.7"
