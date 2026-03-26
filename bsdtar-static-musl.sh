#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

setup_tools

echo -e "${VIOLET}= fetching latest bsdtar version${NC}"
BSDTAR_VERSION=$(gh_latest_release "libarchive/libarchive" '.tag_name | ltrimstr("v")') || true
if [ -z "${BSDTAR_VERSION}" ]; then
  echo -e "${TAWNY}= GitHub API unavailable, falling back to bsdtar 3.8.6${NC}"
  BSDTAR_VERSION="3.8.6"
fi

PACKAGE_VERSION="${BSDTAR_VERSION}"
BSDTAR_TARBALL="libarchive-${BSDTAR_VERSION}.tar.xz"
BSDTAR_MIRRORS=(
  "https://github.com/libarchive/libarchive/releases/download/v${BSDTAR_VERSION}/libarchive-${BSDTAR_VERSION}.tar.xz"
  "https://mirror.fcix.net/slackware/slackware-current/source/l/libarchive/libarchive-${BSDTAR_VERSION}.tar.xz"
  "https://sources.voidlinux.org/libarchive-${BSDTAR_VERSION}/libarchive-${BSDTAR_VERSION}.tar.xz"
  "https://ftp2.osuosl.org/pub/blfs/svn/l/libarchive-${BSDTAR_VERSION}.tar.xz"
  "https://ftp.fau.de/macports/distfiles/libarchive/libarchive-${BSDTAR_VERSION}.tar.xz"
)

run_build_setup "libarchive" "${BSDTAR_VERSION}" "${BSDTAR_TARBALL}" \
  -- "${BSDTAR_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base ccache make pkgconfig zlib-dev zlib-static xz-dev xz-static \
  zstd-dev zstd-static lz4-dev lz4-static openssl-dev openssl-libs-static libbz2 bzip2-static \
  libxml2-dev libxml2-static pcre2-dev pcre2-static lzo-dev
apk upgrade musl-dev --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
chmod 755 upx
echo -e "${LIME}= Extracting source${NC}"
tar xf ${BSDTAR_TARBALL}
cd libarchive-${BSDTAR_VERSION}/
echo -e "${PEACH}= Configure source${NC}"
./configure CC=gcc --disable-shared --enable-static --enable-bsdtar=static --disable-bsdcat \
  --disable-bsdcpio --with-zlib --disable-maintainer-mode --with-bz2lib --with-lzo2 \
  --disable-dependency-tracking --enable-bsdtar --enable-bsdtar=static --disable-bsdunzip \
  --disable-rpath --enable-year2038 --enable-posix-regex-lib=libpcre2posix \
  LDFLAGS='${BASE_LDFLAGS} -w -Wl,-s' PKG_CONFIG='${BASE_PKGCFG}' CFLAGS='${BASE_CFLAGS} ${ARCH_FLAGS} ${EXTRA_CFLAGS} ${LTOFLAGS}'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
gcc -static -o bsdtar tar/bsdtar-bsdtar.o tar/bsdtar-cmdline.o tar/bsdtar-creation_set.o \
  tar/bsdtar-read.o tar/bsdtar-subst.o tar/bsdtar-util.o \
  tar/bsdtar-write.o .libs/libarchive.a .libs/libarchive_fe.a \
  -lz -lbz2 -llzma -lzstd -llz4 -lxml2 -lcrypto -lssl -llzo2 \
  -lpcre2-posix -lpcre2-8
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip bsdtar
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
../upx --lzma bsdtar
EOF

package_output "bsdtar" "./${CHROOTDIR}/libarchive-${BSDTAR_VERSION}/bsdtar"
