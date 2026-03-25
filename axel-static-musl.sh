#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

setup_tools

AXEL_VERSION=$(gh_latest_release "axel-download-accelerator/axel" '.tag_name | ltrimstr("v")') || true
if [ -z "${AXEL_VERSION}" ]; then
  echo -e "${TAWNY}= GitHub API unavailable, falling back to axel 2.17.14${NC}"
  AXEL_VERSION="2.17.14"
fi

PACKAGE_VERSION="${AXEL_VERSION}"
AXEL_TARBALL="axel-${AXEL_VERSION}.tar.xz"
AXEL_MIRRORS=(
  "https://github.com/axel-download-accelerator/axel/releases/download/v${AXEL_VERSION}/axel-${AXEL_VERSION}.tar.xz"
  "https://bos.us.distfiles.macports.org/axel/axel-${AXEL_VERSION}.tar.xz"
  "http://download.nus.edu.sg/mirror/gentoo/distfiles/d5/axel-${AXEL_VERSION}.tar.xz"
  "https://mse.uk.distfiles.macports.org/axel/axel-${AXEL_VERSION}.tar.xz"
  "https://mirror.ismdeep.com/axel/v${AXEL_VERSION}/axel-${AXEL_VERSION}.tar.xz"
  "https://code.opensuse.org/package/axel/blob/master/f/axel-${AXEL_VERSION}.tar.xz"
)

run_build_setup "axel" "${AXEL_VERSION}" "${AXEL_TARBALL}" \
  -- "${AXEL_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base musl-dev ccache openssl-dev zlib-dev libidn2-dev libpsl-dev libidn2-static openssl-libs-static zlib-static libpsl-static libunistring-dev libunistring-static clang
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
chmod 755 upx
echo -e "${LIME}= Extracting source${NC}"
tar xf axel-${AXEL_VERSION}.tar.xz
cd axel-${AXEL_VERSION}/
echo -e "${PEACH}= Configure source${NC}"
./configure CC=clang LDFLAGS='-static -Wl,--gc-sections' PKG_CONFIG='pkg-config --static' \
  CFLAGS='-Os -static ${ARCH_FLAGS} -ffunction-sections -fdata-sections -fomit-frame-pointer -fno-stack-protector -no-pie -Wno-unterminated-string-initialization'
echo -e "${VIOLET}= Building...${NC}"
CC=clang make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip axel
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
../upx --lzma axel
EOF

package_output "axel" "./${CHROOTDIR}/axel-${AXEL_VERSION}/axel"
