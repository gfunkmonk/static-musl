#!/bin/bash
set -euo pipefail
. $(dirname "${BASH_SOURCE[0]}")/common.sh

echo -e "${AQUA}= fetching latest aria2 version${NC}"
ARIA2_VERSION=$(get_version release "aria2/aria2" '.tag_name | ltrimstr("release-")' "1.37.0")
echo -e "${MINT}= building aria2 version: ${ARIA2_VERSION}${NC}"
PACKAGE_VERSION="${ARIA2_VERSION}"
ARIA2_TARBALL="aria2-${ARIA2_VERSION}.tar.gz"
ARIA2_MIRRORS=(
  "https://github.com/aria2/aria2/releases/download/release-${ARIA2_VERSION}/aria2-${ARIA2_VERSION}.tar.gz"
  "https://fossies.org/linux/www/aria2-${ARIA2_VERSION}.tar.gz"
  "https://sources.voidlinux.org/aria2-${ARIA2_VERSION}/aria2-${ARIA2_VERSION}.tar.gz"
  "https://mirrors.lug.mtu.edu/gentoo/distfiles/aria2-${ARIA2_VERSION}.tar.gz"
  "https://ftp.fau.de/macports/distfiles/aria2/aria2-${ARIA2_VERSION}.tar.gz"
)

run_build_setup "aria2" "${ARIA2_VERSION}" "${ARIA2_TARBALL}" \
  "aria2.patch" \
  -- "${ARIA2_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache openssl-dev openssl-libs-static zlib-dev zlib-static libpsl-dev libpsl-static libidn2-static c-ares-dev \
  libssh2-dev libssh2-static sqlite-dev sqlite-static libxml2-dev libxml2-static util-linux-static xz-dev xz-static patch pkgconfig
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${ARIA2_TARBALL}
cd aria2-${ARIA2_VERSION}/
echo -e "${LAGOON}= Applying custom patch(es)${NC}"
patch -p1 --fuzz=4 < ../aria2.patch
echo -e "${PEACH}= Configure source${NC}"
./configure CC=gcc ARIA2_STATIC=yes --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt \
  --without-gnutls --with-openssl --with-libcares --disable-bittorrent --with-sqlite3 \
  --enable-static --disable-shared --disable-nls --disable-rpath \
  LDFLAGS='${BLDFLAGS} ${MOLD} -no-pie -w -Wl,-s' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fno-PIE -Wno-unterminated-string-initialization'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip src/aria2c
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
upx --lzma src/aria2c
echo -e "${CARIBBEAN}= ccache statistics:${NC}"
ccache -s
EOF

package_output "aria2c" "./${CHROOTDIR}/aria2-${ARIA2_VERSION}/src/aria2c"
