#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

setup_tools

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

sudo chroot "./${CHROOTDIR}/" /bin/sh -c "set -e && apk update && apk add build-base \
musl-dev \
ccache \
bash \
make \
python3 \
perl \
linux-headers \
openssl-libs-static \
openssl-dev \
libpcap-dev \
autoconf \
automake \
libtool && \
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH && \
mkdir -p ${CCACHE_LOG_DIR:-/var/log/ccache} && \
chmod 755 upx && \
tar xf nmap-${NMAP_VERSION}.tar.bz2 && \
cd nmap-${NMAP_VERSION}/ && \
patch -p1 --fuzz=4 < ../nmap.patch && \
./configure CC='gcc -static -fPIC' CXX='g++ -static -static-libstdc++ -fPIC' \
  --without-ndiff --without-zenmap --without-nmap-update --with-pcap=linux \
  --with-openssl --without-liblua --without-libssh2 --without-nping --without-ncat \
  LDFLAGS='-static -Wl,--gc-sections' PKG_CONFIG='pkg-config --static' \
  CFLAGS='-Os -static -ffunction-sections -fdata-sections -fomit-frame-pointer -fno-stack-protector -no-pie' && \
make -j\$(nproc) && \
strip nmap && \
../upx --brute nmap"

package_output "nmap" "./${CHROOTDIR}/nmap-${NMAP_VERSION}/nmap"
