#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${VIOLET}= fetching latest nmap version${NC}"
NMAP_VERSION=$("${CURL}" -s https://nmap.org/dist/ | grep -o 'href="[^"]*.tar.bz2"' | cut -d'"' -f2 | sort | tail -1 | sed 's/\.tar.*//' | sed 's/nmap-//g')
[[ -z "${NMAP_VERSION}" ]] && { echo -e "${TAWNY}= nmap.org fetch failed, using fallback ${FALLBACK_NMAP}${NC}" >&2; NMAP_VERSION="${FALLBACK_NMAP}"; }
echo -e "${TEAL}= building nmap version: ${NMAP_VERSION}${NC}"
PACKAGE_VERSION="${NMAP_VERSION}"
NMAP_TARBALL="nmap-${NMAP_VERSION}.tar.bz2"
NMAP_MIRRORS=(
  "https://nmap.org/dist/nmap-${NMAP_VERSION}.tar.bz2"
  "https://fossies.org/linux/misc/nmap-${NMAP_VERSION}.tar.bz2"
  "https://ftp2.osuosl.org/pub/blfs/development/n/nmap-${NMAP_VERSION}.tar.bz2"
)

run_build_setup "nmap" "${NMAP_VERSION}" "${NMAP_TARBALL}" \
  "dont_define_strlcat_in_libdnet.patch" \
  "upstream-Fix-incompatible-pointer-type-error.patch" \
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
patch -p1 --fuzz=4 < ../dont_define_strlcat_in_libdnet.patch
patch -p1 --fuzz=4 < ../upstream-Fix-incompatible-pointer-type-error.patch
echo -e "${PEACH}= Configure source${NC}"
./configure CC='${CC} -static' CXX='${CXX} -static -static-libstdc++' \
  --without-ndiff --without-zenmap --without-nmap-update --with-pcap=linux \
  --with-openssl --without-liblua --without-libssh2 --without-nping --without-ncat \
  LDFLAGS='${BLDFLAGS} ${MOLD} ${NOPIE}' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${NOPIE}'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "nmap" "./${CHROOTDIR}/nmap-${NMAP_VERSION}/nmap"
