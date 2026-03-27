#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

echo -e "${VIOLET}= fetching latest lftp version${NC}"
LFTP_VERSION=$(gh_latest_release "lavv17/lftp" '.tag_name | ltrimstr("v")') || true
if [ -z "${LFTP_VERSION}" ]; then
  echo -e "${TAWNY}= GitHub API unavailable, falling back to lftp 4.9.3${NC}"
  LFTP_VERSION="4.9.3"
fi

PACKAGE_VERSION="${LFTP_VERSION}"
LFTP_TARBALL="lftp-${LFTP_VERSION}.tar.gz"
LFTP_MIRRORS=(
  "https://github.com/lavv17/lftp/releases/download/v${LFTP_VERSION}/lftp-${LFTP_VERSION}.tar.gz"
  "https://fossies.org/linux/misc/lftp-${LFTP_VERSION}.tar.gz"
  "https://ftp.fau.de/macports/distfiles/lftp/lftp-${LFTP_VERSION}.tar.gz"
)

run_build_setup "lftp" "${LFTP_VERSION}" "${LFTP_TARBALL}" \
  "lftp.patch" \
  "lftp-4.9.1-libdir-readline.patch" \
  "lftp-4.9.2-socks.patch" \
  "lftp-4.9.3-gnulib-stdlib.h.patch" \
  "lftp-4.9.3-gnulib.patch" \
  -- "${LFTP_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache autoconf automake libtool linux-headers expat-dev \
  expat-static libidn-dev libunistring-dev libunistring-static pkgconfig ncurses-dev \
  ncurses-static openssl-dev openssl-libs-static readline-dev readline-static zlib-dev \
  zlib-static libstdc++-dev gettext-dev gettext-static
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${LFTP_TARBALL}
cd lftp-${LFTP_VERSION}/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../lftp.patch
patch -p1 --fuzz=4 < ../lftp-4.9.1-libdir-readline.patch
patch -p1 --fuzz=4 < ../lftp-4.9.2-socks.patch
patch -p1 --fuzz=4 < ../lftp-4.9.3-gnulib-stdlib.h.patch
patch -p1 --fuzz=4 < ../lftp-4.9.3-gnulib.patch
echo -e "${PEACH}= Configure source${NC}"
autoreconf -f -i
./configure CC=gcc CXX=g++ LIBS='-l:libreadline.a -l:libncursesw.a' --with-openssl=yes --without-gnutls \
  --enable-static --enable-threads=posix --disable-nls --disable-shared --disable-rpath --disable-silent-rules \
  --disable-ipv6 --enable-year2038 --with-readline=yes --with-expat=yes  \
  LDFLAGS='${BLDFLAGS} ${MOLD} -no-pie -w -Wl,-s' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fno-PIE -std=c17 -Wno-unterminated-string-initialization -Wno-deprecated-declarations' \
  CXXFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} -fno-PIE -std=c++17 -Wno-deprecated-declarations -Wno-error=template-id-cdtor'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc) LDFLAGS='-static -all-static''
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip src/lftp
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
upx --lzma src/lftp
EOF

package_output "lftp" "./${CHROOTDIR}/lftp-${LFTP_VERSION}/src/lftp"
