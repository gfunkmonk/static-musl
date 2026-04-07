#!/usr/bin/env bash
set -e

EXTRA_PACKAGES=("$@")

cd "$(dirname "$0")/.."
source "$(dirname "$0")/../common.sh"

setup_arch
[ -f minirootfs/"alpine-base-${ARCH}.tar.zst" ] && rm minirootfs/"alpine-base-${ARCH}.tar.zst"
echo -e "${LAGOON}== Building Master Base Rootfs ==${NC}"
setup_alpine_chroot base-setup

echo -e "${ORANGE}= Installing base toolchain...${NC}"
sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
apk update
apk add --no-cache build-base mold ccache patch sed automake autoconf clang
apk upgrade --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main mold musl-dev
EOF

if [ ${#EXTRA_PACKAGES[@]} -gt 0 ]; then
    echo -e "${SKY}= Installing extra packages: ${EXTRA_PACKAGES[*]}...${NC}"
    # We pass the array as a string to the chroot apk command
    sudo chroot "./${CHROOTDIR}/" apk add --no-cache "${EXTRA_PACKAGES[@]}"
fi

sudo chroot "./${CHROOTDIR}/" /bin/sh -c "rm -rf /var/cache/apk/*"

echo -e "${LIME}= Saving snapshot to alpine-base-${ARCH}.tar.zst...${NC}"
unmount_chroot
sudo tar -cf - -C "${CHROOTDIR}" . | zstd -T0 -15 -o "alpine-base-${ARCH}.tar.zst"
mkdir -p minirootfs/
mv "alpine-base-${ARCH}.tar.zst" minirootfs/

echo -e "${HELIOTROPE}== Done! Future builds will now use this snapshot. ==${NC}"