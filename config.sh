#!/usr/bin/env bash



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

