#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

echo -e "${VIOLET}= fetching latest wget2 version${NC}"
WGET2_VERSION=$(gh_latest_release "rockdaboot/wget2" '.tag_name | ltrimstr("v")') || true
if [ -z "${WGET2_VERSION}" ]; then
  echo -e "${TAWNY}= GitHub API unavailable, falling back to wget2 2.2.1${NC}"
  WGET2_VERSION="2.2.1"
fi

PACKAGE_VERSION="${WGET2_VERSION}"
WGET2_TARBALL="wget2-${WGET2_VERSION}.tar.lz"
WGET2_MIRRORS=(
  "https://ftp.gnu.org/gnu/wget/wget2-${WGET2_VERSION}.tar.lz"
  "https://fossies.org/linux/www/wget2-${WGET2_VERSION}.tar.lz"
  "https://mirrors.kernel.org/slackware/slackware-current/source/n/wget2/wget2-${WGET2_VERSION}.tar.lz"
)

run_build_setup "wget2" "${WGET2_VERSION}" "${WGET2_TARBALL}" \
  -- "${WGET2_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base ccache openssl-dev zlib-dev libidn2-dev libpsl-dev libidn2-static openssl-libs-static \
  zlib-static libpsl-static libunistring-dev libunistring-static patch texinfo pcre2-dev pcre2-static perl c-ares-dev \
  bzip2-dev bzip2-static xz-dev xz-static lz4-dev lz4-static zstd-dev zstd-static libpsl-dev libpsl-static nghttp2-static nghttp2-dev
apk upgrade musl-dev --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
7zz x -so ${WGET2_TARBALL} | tar xf - -C /
cd wget2-${WGET2_VERSION}/
#echo -e "${LAGOON}= Applying custom patch${NC}"
#patch -p1 --fuzz=4 < ../wget2-passive-ftp.patch
echo -e "${PEACH}= Configure source${NC}"
./configure CC=gcc --with-ssl=openssl --disable-nls --disable-rpath --sysconfdir=/etc --disable-silent-rules  \
  --disable-ipv6 --enable-year2038  --with-cares --with-openssl=yes --disable-shared --enable-static --disable-doc \
  LDFLAGS='${BLDFLAGS} -static-pie -w -Wl,-s -lidn2 -lunistring' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fPIE -Wno-unterminated-string-initialization' \
  PERL=/usr/bin/perl
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip src/wget2
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
upx --lzma src/wget2
EOF

package_output "wget2" "./${CHROOTDIR}/wget2-${WGET2_VERSION}/src/wget2"
