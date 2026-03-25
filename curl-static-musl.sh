#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

setup_tools

echo -e "${VIOLET}= fetching latest curl version${NC}"
CURL_VERSION=$(gh_latest_release "curl/curl" '.tag_name | ltrimstr("curl-") | gsub("_"; ".")') || true
if [ -z "${CURL_VERSION}" ]; then
  echo -e "${TAWNY}= GitHub API unavailable, falling back to curl 8.19.0${NC}"
  CURL_VERSION="8.19.0"
fi

PACKAGE_VERSION="${CURL_VERSION}"
CURL_GIT_VER="${CURL_VERSION//./_}"
CURL_TARBALL="curl-${CURL_VERSION}.tar.xz"
CURL_MIRRORS=(
  "https://curl.se/download/curl-${CURL_VERSION}.tar.xz"
  "https://github.com/curl/curl/releases/download/curl-${CURL_GIT_VER}/curl-${CURL_VERSION}.tar.xz"
  "https://mirrors.omnios.org/curl/curl-${CURL_VERSION}.tar.xz"
  "https://mirrors.slackware.com/slackware/slackware-current/source/n/curl/curl-${CURL_VERSION}.tar.xz"
  "https://ftp.belnet.be/mirror/rsync.gentoo.org/gentoo/distfiles/e8/curl-${CURL_VERSION}.tar.xz"
  "https://mirror.ircam.fr/pub/OpenBSD/distfiles/curl-${CURL_VERSION}.tar.xz"
)

run_build_setup "curl" "${CURL_VERSION}" "${CURL_TARBALL}" \
  "curl.patch" \
  -- "${CURL_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
if [ "$ARCH" = "x86" ]; then
  apk update && apk add build-base musl-dev ccache openssl-dev openssl-libs-static nghttp2-dev nghttp2-static libssh2-dev libssh2-static zlib-dev zlib-static zstd-dev zstd-static autoconf automake libunistring-static libunistring-dev libidn2-static libidn2-dev libpsl-static libpsl-dev
else
  apk update && apk add build-base musl-dev ccache openssl-dev openssl-libs-static nghttp2-dev nghttp2-static libssh2-dev libssh2-static zlib-dev zlib-static zstd-dev zstd-static autoconf automake libunistring-static libunistring-dev libidn2-static libidn2-dev libpsl-static libpsl-dev clang
fi
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
chmod 755 upx
echo -e "${LIME}= Extracting source${NC}"
tar xf curl-${CURL_VERSION}.tar.xz
cd curl-${CURL_VERSION}/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../curl.patch
echo -e "${PEACH}= Configure source${NC}"
if [ "$ARCH" = "x86" ]; then
  ./configure \
    --disable-shared --enable-static \
    --disable-ldap --enable-ipv6 --enable-unix-sockets \
    --with-ssl --with-libssh2 \
    --disable-docs --disable-manual --without-libpsl \
    CC=gcc LDFLAGS='-static -Wl,--gc-sections' PKG_CONFIG='pkg-config --static' \
    CFLAGS='-Os -static ${ARCH_FLAGS} -ffunction-sections -fdata-sections -fomit-frame-pointer -fno-stack-protector -no-pie -Wno-unterminated-string-initialization'
    echo -e "${VIOLET}= Building...${NC}"
    CC=gcc make -j\$(nproc) V=1 LDFLAGS='-static -all-static'
else
  ./configure \
    --disable-shared --enable-static \
    --disable-ldap --enable-ipv6 --enable-unix-sockets \
    --with-ssl --with-libssh2 \
    --disable-docs --disable-manual --without-libpsl \
    CC=clang LDFLAGS='-static -Wl,--gc-sections' PKG_CONFIG='pkg-config --static' \
    CFLAGS='-Os -static ${ARCH_FLAGS} -ffunction-sections -fdata-sections -fomit-frame-pointer -fno-stack-protector -no-pie -Wno-unterminated-string-initialization'
    echo -e "${VIOLET}= Building...${NC}"
    CC=clang make -j\$(nproc) V=1 LDFLAGS='-static -all-static'
fi
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip src/curl
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
../upx --lzma src/curl
EOF

package_output "curl" "./${CHROOTDIR}/curl-${CURL_VERSION}/src/curl"
