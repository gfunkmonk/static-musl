#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

echo -e "${JUNEBUD}= fetching latest dropbear version${NC}"
DROPBEAR_VERSION=$(gh_latest_release "mkj/dropbear" '.tag_name | ltrimstr("DROPBEAR_")') || true
if [ -z "${DROPBEAR_VERSION}" ]; then
  echo -e "${BOYSENBERRY}= GitHub API unavailable, falling back to dropbear 2025.88${NC}"
  DROPBEAR_VERSION="2025.88"
fi

PACKAGE_VERSION="${DROPBEAR_VERSION}"
DROPBEAR_TARBALL="dropbear-${DROPBEAR_VERSION}.tar.bz2"
DROPBEAR_MIRRORS=(
  "https://matt.ucc.asn.au/dropbear/releases/dropbear-${DROPBEAR_VERSION}.tar.bz2"
  "https://dropbear.nl/mirror/releases/dropbear-${DROPBEAR_VERSION}.tar.bz2"
)

run_build_setup "dropbear" "${DROPBEAR_VERSION}" "${DROPBEAR_TARBALL}" \
  -- "${DROPBEAR_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${HELIOTROPE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache openssl-dev openssl-libs-static zlib-dev zlib-static
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LEMON}= Extracting source${NC}"
tar xf ${DROPBEAR_TARBALL}
cd dropbear-${DROPBEAR_VERSION}/
sed -i 's|dropbear dbclient dropbearkey dropbearconvert|dropbear dbclient dropbearkey dropbearconvert scp|g' Makefile.in
echo -e "${CHARTREUSE}= Configure source${NC}"
./configure CC=gcc \
  --disable-lastlog --disable-utmp --disable-utmpx --disable-wtmp --disable-wtmpx \
  --disable-pututline --disable-pututxline --enable-bundled-libtom --disable-pam \
  --disable-zlib --enable-static \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -Wno-incompatible-pointer-types -Wno-undef' \
  LDFLAGS='${BLDFLAGS} ${MOLD}' PKG_CONFIG='${PKGCFG}'
echo -e "${PURPLE_BLUE}= Building...${NC}"
CC=gcc make -j\$(nproc) MULTI=1
cp dropbearmulti dropbear
echo -e "${INDIGO}= Stripping binary${NC}"
strip dropbear
echo -e "${SKY}= Compressing with UPX${NC}"
upx --lzma dropbear
EOF

package_output "dropbear" "./${CHROOTDIR}/dropbear-${DROPBEAR_VERSION}/dropbear"

## ./configure --disable-syslog --disable-lastlog --disable-utmp --disable-utmpx --disable-wtmp --disable-wtmpx --disable-loginfunc --disable-pututline --disable-pututxline --disable-zlib --enable-static --disable-shadow \
