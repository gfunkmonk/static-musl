#!/bin/bash
set -euo pipefail
. $(dirname "${BASH_SOURCE[0]}")/common.sh

echo -e "${VIOLET}= fetching latest bsdtar version${NC}"
BSDTAR_VERSION=$(get_version release "libarchive/libarchive" ".tag_name | ltrimstr("v")" "3.8.6")
echo -e "${MINT}= building bsdtar version: ${BSDTAR_VERSION}${NC}"
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
apk update && apk add build-base mold ccache make pkgconfig zlib-dev zlib-static xz-dev xz-static \
  zstd-dev zstd-static lz4-dev lz4-static openssl-dev openssl-libs-static libbz2 bzip2-static \
  libxml2-dev libxml2-static lzo-dev
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${BSDTAR_TARBALL}
cd libarchive-${BSDTAR_VERSION}/
echo -e "${PEACH}= Configure source${NC}"
./configure CC=gcc --disable-shared --enable-static --enable-bsdtar=static --disable-bsdcat \
  --disable-bsdcpio --with-zlib --disable-maintainer-mode --with-bz2lib --with-lzo2 \
  --disable-dependency-tracking --disable-bsdunzip --disable-rpath --enable-year2038 \
  LDFLAGS='${BLDFLAGS} -static-pie -w -Wl,-s' PKG_CONFIG='${PKGCFG}' CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fPIE'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
gcc -static -o bsdtar tar/bsdtar-bsdtar.o tar/bsdtar-cmdline.o tar/bsdtar-creation_set.o \
  tar/bsdtar-read.o tar/bsdtar-subst.o tar/bsdtar-util.o \
  tar/bsdtar-write.o .libs/libarchive.a .libs/libarchive_fe.a \
  -lz -lbz2 -llzma -lzstd -llz4 -lxml2 -lcrypto -lssl -llzo2
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip bsdtar
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
upx --lzma bsdtar
EOF

package_output "bsdtar" "./${CHROOTDIR}/libarchive-${BSDTAR_VERSION}/bsdtar"
