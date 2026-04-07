#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${OCHRE}= fetching latest wget2 version${NC}"
WGET2_VERSION=$(get_gitlab_version "gnuwget/wget2" "${FALLBACK_WGET2}")
echo -e "${PURPLE_BLUE}= building wget2 version: ${WGET2_VERSION}${NC}"
PACKAGE_VERSION="${WGET2_VERSION}"
WGET2_TARBALL="wget2-${WGET2_VERSION}.tar.lz"
WGET2_MIRRORS=(
  "https://ftp.gnu.org/gnu/wget/wget2-${WGET2_VERSION}.tar.lz"
  "https://fossies.org/linux/www/wget2-${WGET2_VERSION}.tar.lz"
  "https://mirrors.kernel.org/slackware/slackware-current/source/n/wget2/wget2-${WGET2_VERSION}.tar.lz"
  "https://mirror.retropc.se/slackware/slackware/patches/source/wget2/wget2-${WGET2_VERSION}.tar.lz"
)

run_build_setup "wget2" "${WGET2_VERSION}" "${WGET2_TARBALL}" \
  -- "${WGET2_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache brotli-dev brotli-static bzip2-dev bzip2-static libidn2-dev libidn2-static libpsl-dev \
  libpsl-static libunistring-dev libunistring-static nghttp2-dev nghttp2-static openssl-dev openssl-libs-static pcre2-dev \
  pcre2-static xz-dev xz-static zlib-dev zlib-static zstd-dev zstd-static
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${MAUVE}= Extracting source${NC}"
7zz x -so ${WGET2_TARBALL} | tar xf -
cd wget2-${WGET2_VERSION}/
if [ -d ../patches ]; then
   echo -e "${NEONPINK}= Applying custom patch(es)${NC}"
   for p in ../patches/*; do
       echo -e "${NEONBLUE}Applying \$(basename "\$p")...${NC}"
       patch -p1 --fuzz=4 < "\$p"
   done
fi
echo -e "${PEACH}= Configure source${NC}"
# NO MOLD -- DOESN'T BUILD WITH MOLD #
./configure  CC="${CC}" --with-ssl=openssl \
  --disable-nls --disable-rpath --sysconfdir=/etc --disable-silent-rules --disable-ipv6 --enable-year2038 \
  --disable-shared --enable-static --disable-doc --with-bzip2 --enable-manylibs --with-lzma --with-brotlidec \
  LDFLAGS='${BLDFLAGS} ${LPIE} -lidn2 -lunistring' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CPIE} -Wno-unterminated-string-initialization'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "wget2" "./${CHROOTDIR}/wget2-${WGET2_VERSION}/src/wget2"
