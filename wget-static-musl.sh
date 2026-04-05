#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${MINT}= fetching latest wget version${NC}"
WGET_VERSION=$(get_git_version "https://cgit.git.savannah.gnu.org/cgit/wget.git/refs/tags" "v[0-9]+\.[0-9]+(\.[0-9]+)*" "v" "${FALLBACK_WGET}")
echo -e "${JUNEBUD}= building wget version: ${WGET_VERSION}${NC}"
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
apk update && apk add build-base ccache openssl-dev zlib-dev libidn2-dev libpsl-dev libidn2-static openssl-libs-static \
  zlib-static libpsl-static libunistring-dev libunistring-static patch texinfo pcre2-dev pcre2-static perl c-ares-dev
apk upgrade musl-dev --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${WGET_TARBALL}
cd wget-${WGET_VERSION}/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../wget-passive-ftp.patch
echo -e "${PEACH}= Configure source${NC}"
./configure CC="${CC}" --with-ssl=openssl --disable-nls --disable-rpath --sysconfdir=/etc --disable-silent-rules  \
  --disable-ipv6 --enable-year2038  --with-cares --with-openssl=yes \
  LDFLAGS='${BLDFLAGS} -no-pie -lidn2 -lunistring' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fno-PIE -Wno-unterminated-string-initialization' \
  PERL=/usr/bin/perl
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "wget" "./${CHROOTDIR}/wget-${WGET_VERSION}/src/wget"
