#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

setup_tools

LFTP_VERSION="4.9.3"
PACKAGE_VERSION="${LFTP_VERSION}"
LFTP_TARBALL="lftp-${LFTP_VERSION}.tar.gz"
LFTP_MIRRORS=(
  "https://github.com/lavv17/lftp/releases/download/v${LFTP_VERSION}/lftp-${LFTP_VERSION}.tar.gz"
  "https://fossies.org/linux/misc/lftp-${LFTP_VERSION}.tar.gz"
  "https://ftp.fau.de/macports/distfiles/lftp/lftp-${LFTP_VERSION}.tar.gz"
)

run_build_setup "lftp" "${LFTP_VERSION}" "${LFTP_TARBALL}" \
  "lftp.patch" \
  -- "${LFTP_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base musl-dev ccache autoconf automake libtool linux-headers expat-dev expat-static libidn-dev libunistring-dev libunistring-static pkgconfig ncurses-dev ncurses-static openssl-dev openssl-libs-static readline-dev readline-static zlib-dev zlib-static libstdc++-dev gettext-dev gettext-static
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
chmod 755 upx
echo -e "${LIME}= Extracting source${NC}"
tar xf lftp-${LFTP_VERSION}.tar.gz
cd lftp-${LFTP_VERSION}/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../lftp.patch
autoreconf -i -f
echo -e "${PEACH}= Configure source${NC}"
./configure CC=gcc CXX=g++ LIBS='-l:libreadline.a -l:libncursesw.a' \
  --with-openssl --without-gnutls --enable-static --enable-threads=posix --disable-nls --disable-shared \
  LDFLAGS='-static -Wl,--gc-sections' PKG_CONFIG='pkg-config --static' \
  CFLAGS='-Os -static  ${ARCH_FLAGS} -ffunction-sections -fdata-sections -fomit-frame-pointer -fno-stack-protector -std=c17 -Wno-unterminated-string-initialization -Wno-deprecated-declarations -no-pie' \
  CXXFLAGS='-Os -static  ${ARCH_FLAGS} -ffunction-sections -fdata-sections -fomit-frame-pointer -fno-stack-protector -std=c++14 -Wno-deprecated-declarations -Wno-error=template-id-cdtor'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc) LDFLAGS='-static -all-static -Wl,--gc-sections'
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip src/lftp
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
../upx --lzma src/lftp
EOF

package_output "lftp" "./${CHROOTDIR}/lftp-${LFTP_VERSION}/src/lftp"
