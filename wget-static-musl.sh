#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

setup_tools

WGET_VERSION="1.25.0"
PACKAGE_VERSION="${WGET_VERSION}"
WGET_TARBALL="wget-${WGET_VERSION}.tar.gz"
WGET_MIRRORS=(
  "https://gnu.askapache.com/wget/wget-${WGET_VERSION}.tar.gz"
  "https://mirror.team-cymru.com/gnu/wget/wget-${WGET_VERSION}.tar.gz"
  "https://ftp.wayne.edu/gnu/wget/wget-${WGET_VERSION}.tar.gz"
  "https://mirror.us-midwest-1.nexcess.net/gnu/wget/wget-${WGET_VERSION}.tar.gz"
  "https://mirrors.ibiblio.org/gnu/wget/wget-${WGET_VERSION}.tar.gz"
  "https://mirror.csclub.uwaterloo.ca/gnu/wget/wget-${WGET_VERSION}.tar.gz"
)

run_build_setup "wget" "${WGET_VERSION}" "${WGET_TARBALL}" \
  "wget-passive-ftp.patch" \
  -- "${WGET_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base ccache openssl-dev zlib-dev libidn2-dev libpsl-dev libidn2-static openssl-libs-static zlib-static libpsl-static libunistring-dev libunistring-static patch texinfo pcre2-dev pcre2-static perl
apk upgrade musl-dev --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
chmod 755 upx
echo -e "${LIME}= Extracting source${NC}"
tar xf wget-${WGET_VERSION}.tar.gz
cd wget-${WGET_VERSION}/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../wget-passive-ftp.patch
echo -e "${PEACH}= Configure source${NC}"
./configure CC=gcc --with-ssl=openssl --with-libidn --disable-nls \
  --disable-rpath --sysconfdir=/etc \
  LDFLAGS='-static -lidn2 -lunistring -Wl,--gc-sections' \
  PKG_CONFIG='pkg-config --static' \
  CFLAGS='-Os -static ${ARCH_FLAGS} -ffunction-sections -fdata-sections -fomit-frame-pointer -fno-stack-protector -no-pie -Wno-unterminated-string-initialization' \
  PERL=/usr/bin/perl
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip src/wget
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
../upx --lzma src/wget
EOF

package_output "wget" "./${CHROOTDIR}/wget-${WGET_VERSION}/src/wget"
