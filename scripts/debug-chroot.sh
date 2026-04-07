#!/usr/bin/env bash
set -e

# Change to the repository root
cd "$(dirname "$0")/.."

# Source your common.sh
SCRIPT_DIR="$(pwd)"
if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then
    . "${SCRIPT_DIR}/common.sh"
else
    echo "common.sh not found in ${SCRIPT_DIR}"
    exit 1
fi

export CHROOTDIR="debug-chroot-${ARCH:-native}"
export KEEP_CHROOT="true"

echo -e "${SKY}= Preparing debug environment in ${CHROOTDIR}...${NC}"

setup_arch
setup_alpine_chroot "base-setup"
setup_qemu
mount_chroot

echo -e "${JUNEBUD}>>> Entering Chroot: ${CHROOTDIR}${NC}"
echo -e "${PEACH}Note: Mounts remain active. Use KEEP_CHROOT=false or manual umount to clean.${NC}"

sudo chroot "./${CHROOTDIR}" /bin/sh

echo -e "${VIOLET}= Shell exited.${NC}"
echo -e "${TOMATO}= To unmount manually: ${BWHITE}sudo umount -nfR ./${CHROOTDIR}/{dev/pts,dev,proc,sys,tmp,run,ccache}${NC}"