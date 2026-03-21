#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

setup_tools

echo -e "${VIOLET}= fetching latest htop version${NC}"
HTOP_VERSION=$(gh_latest_release "htop-dev/htop") || true
if [ -z "${HTOP_VERSION}" ]; then
  echo -e "${TAWNY}= GitHub API unavailable, falling back to htop 3.4.1${NC}"
  HTOP_VERSION="3.4.1"
fi

PACKAGE_VERSION="${HTOP_VERSION}"
HTOP_TARBALL="htop-${HTOP_VERSION}.tar.xz"
HTOP_MIRRORS=(
  "https://github.com/htop-dev/htop/releases/download/${HTOP_VERSION}/htop-${HTOP_VERSION}.tar.xz"
  "https://fossies.org/linux/misc/htop-${HTOP_VERSION}.tar.xz"
)

run_build_setup "htop" "${HTOP_VERSION}" "${HTOP_TARBALL}" \
  "htop.patch" \
  -- "${HTOP_MIRRORS[@]}"

# OPTIMIZATION: Use COMMON_BUILD_DEPS from common.sh
# Skip apk update if rootfs is fresh (< 1 day old)
sudo chroot "./${CHROOTDIR}/" /bin/sh -c "set -e && \
[ -f /.rootfs-fresh ] || apk update && \
rm -f /.rootfs-fresh && \
apk add ${COMMON_BUILD_DEPS} \
pkgconfig \
ncurses-dev \
ncurses-static \
python3 \
lm-sensors-dev \
libnl3-dev \
libnl3-static \
linux-headers && \
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH && \
chmod 755 upx && \
tar xf ${HTOP_TARBALL} && \
cd htop-${HTOP_VERSION}/ && \
patch -p1 --fuzz=4 < ../htop.patch && \
./configure CC='gcc' \
  --enable-unicode --enable-static --enable-affinity --enable-delayacct \
  LDFLAGS='-static -Wl,--gc-sections' PKG_CONFIG='pkg-config --static' \
  CFLAGS='-Os -static -ffunction-sections -fdata-sections -fomit-frame-pointer -fno-stack-protector -no-pie' && \
CC='gcc' make -j\$(nproc) && \
strip htop && \
../upx --lzma htop"

package_output "htop" "./${CHROOTDIR}/htop-${HTOP_VERSION}/htop"