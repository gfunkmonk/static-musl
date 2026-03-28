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
EXTRA="-fshort-enums -fno-ident -fno-unwind-tables -fno-asynchronous-unwind-tables"
LTO="-flto=auto -ffat-lto-objects"

# Linker Flags
MOLD="-fuse-ld=mold"
BFD="-fuse-ld=bfd"
BLDFLAGS="-static -Wl,--gc-sections"

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

# CCACHE gets its panties in a knot if the host has log_file defined and it doesn't exist in the chroot when the
# CCACHE directories are bind mounted. This was the best way I could find to get that string to make the directory.
CCACHE_LOG_DIR=$(ccache -p 2>/dev/null | grep log_file | cut -d "=" -f2 | rev | cut -d'/' -f2- | rev | sed 's/ //g') || true
: "${CCACHE_LOG_DIR:=/var/log/ccache}"

# Set KEEP_CHROOT=true via environment to preserve chroot after failed builds (for debugging)
: "${KEEP_CHROOT:=false}"






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
CARIBBEAN="\033[38;2;0;204;153m"
NC="\033[0m"
