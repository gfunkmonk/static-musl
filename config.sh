#!/bin/bash

################################################################################
#     .oooooo.     .oooooo.   ooooo      ooo oooooooooooo ooooo   .oooooo.     #
#    d8P'  `Y8b   d8P'  `Y8b  `888b.     `8' `888'     `8 `888'  d8P'  `Y8b    #
#   888          888      888  8 `88b.    8   888          888  888            #
#   888          888      888  8   `88b.  8   888oooo8     888  888            #
#   888          888      888  8     `88b.8   888    "     888  888     ooooo  #
#   `88b    ooo  `88b    d88'  8       `888   888          888  `88.    .88'   #
#    `Y8bood8P'   `Y8bood8P'  o8o        `8  o888o        o888o  `Y8bood8P'    #
################################################################################

# Set directory name for the target chroot
: "${CHROOTDIR:=potato}"

# CCACHE_CHROOT_DIR: path inside the chroot where ccache stores its cache.
# Set this to a host-mounted path (e.g. via CI cache) to persist ccache across
# builds.
# Defaults to /ccache (ephemeral, inside the chroot).
: "${CCACHE_CHROOT_DIR:=/ccache}"

# CCACHE gets its panties in a knot if the host has log_file defined and it doesn't
# exist in the chroot when the CCACHE directories are bind mounted. This was the best
# way I could find to get that string to make the directory.
CCACHE_LOG_DIR=$(ccache -p 2>/dev/null | grep log_file | cut -d "=" -f2 | rev | cut -d'/' -f2- | rev | sed 's/ //g') || true
: "${CCACHE_LOG_DIR:=/var/log/ccache}"

# Set KEEP_CHROOT=true via environment to preserve chroot after failed
# builds (for debugging)
: "${KEEP_CHROOT:=false}"

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

