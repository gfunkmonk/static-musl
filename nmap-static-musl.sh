#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

NMAP_VERSION="7.98"
PACKAGE_VERSION="${NMAP_VERSION}"
NMAP_TARBALL="nmap-${NMAP_VERSION}.tar.bz2"
NMAP_MIRRORS=(
  "https://nmap.org/dist/nmap-${NMAP_VERSION}.tar.bz2"
  "https://fossies.org/linux/misc/nmap-${NMAP_VERSION}.tar.bz2"
  "https://ftp2.osuosl.org/pub/blfs/development/n/nmap-${NMAP_VERSION}.tar.bz2"
)

run_build_setup "nmap" "${NMAP_VERSION}" "${NMAP_TARBALL}" \
  "nmap.patch" \
  -- "${NMAP_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache bash make python3 perl linux-headers openssl-libs-static openssl-dev libpcap-dev \
  autoconf automake libtool zlib-dev zlib-static
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${NMAP_TARBALL}
cd nmap-${NMAP_VERSION}/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../nmap.patch
echo -e "${PEACH}= Configure source${NC}"
./configure CC='gcc -static' CXX='g++ -static -static-libstdc++' \
  --without-ndiff --without-zenmap --without-nmap-update --with-pcap=linux \
  --with-openssl --without-liblua --without-libssh2 --without-nping --without-ncat \
  LDFLAGS='${BLDFLAGS} ${MOLD} -static-pie -w -Wl,-s' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fPIE'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip nmap
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
upx --lzma nmap
EOF

package_output "nmap" "./${CHROOTDIR}/nmap-${NMAP_VERSION}/nmap"
