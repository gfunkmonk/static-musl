#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

echo -e "${VIOLET}= fetching latest xz version${NC}"
XZ_VERSION=$(gh_latest_release "tukaani-project/xz" '.tag_name | ltrimstr("v")') || true
if [ -z "${XZ_VERSION}" ]; then
  echo -e "${TAWNY}= GitHub API unavailable, falling back to xz 5.8.2${NC}"
  XZ_VERSION="5.8.2"
fi

PACKAGE_VERSION="${XZ_VERSION}"
XZ_TARBALL="xz-${XZ_VERSION}.tar.xz"
XZ_MIRRORS=(
  "https://github.com/tukaani-project/xz/releases/download/v${XZ_VERSION}/xz-${XZ_VERSION}.tar.xz"
  "https://netactuate.dl.sourceforge.net/project/lzmautils/xz-${XZ_VERSION}.tar.xz"
  "https://www.mirrorservice.org/pub/slackware/slackware-current/source/a/xz/xz-${XZ_VERSION}.tar.xz"
  "https://m3-container.net/M3_Container/oss_packages/xz-${XZ_VERSION}.tar.xz"
)

run_build_setup "xz" "${XZ_VERSION}" "${XZ_TARBALL}" \
  -- "${XZ_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base ccache pkgconfig clang
apk upgrade musl-dev --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
chmod 755 upx
echo -e "${LIME}= Extracting source${NC}"
tar xf ${XZ_TARBALL}
cd xz-${XZ_VERSION}/
echo -e "${PEACH}= Configure source${NC}"
./configure CC=clang --enable-static --disable-shared --disable-nls --enable-small \
  --enable-lzip-decoder --enable-threads=yes --disable-silent-rules --disable-rpath \
  --enable-largefile --enable-year2038 \
  LDFLAGS='${BASE_LDFLAGS} -w -Wl,-s' PKG_CONFIG='${BASE_PKGCFG}' \
  CFLAGS='${BASE_CFLAGS} ${ARCH_FLAGS} ${EXTRA_CFLAGS} ${LTOFLAGS} -Wno-unterminated-string-initialization'
echo -e "${VIOLET}= Building...${NC}"
CC=clang LDFLAGS='${BASE_LDFLAGS} -w -Wl,-s' make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip src/xz/xz
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
../upx --lzma src/xz/xz
EOF

package_output "xz" "./${CHROOTDIR}/xz-${XZ_VERSION}/src/xz/xz"
