#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${VIOLET}= fetching latest less version${NC}"
LESS_VERSION=$(get_version tag "gwsw/less" '.[0].name | ltrimstr("v")' "${FALLBACK_LESS}")
echo -e "${TEAL}= building less version: ${LESS_VERSION}${NC}"
PACKAGE_VERSION="${LESS_VERSION}"
LESS_TARBALL="less-${LESS_VERSION}.tar.gz"
LESS_MIRRORS=(
  "https://github.com/gwsw/less/archive/v${LESS_VERSION}/less-${LESS_VERSION}.tar.gz"
  "https://www.greenwoodsoftware.com/less/less-${LESS_VERSION}.tar.gz"
)

run_build_setup "less" "${LESS_VERSION}" "${LESS_TARBALL}" \
  -- "${LESS_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache pkgconfig pcre2-static pcre2-dev ncurses-dev \
  ncurses-static perl autoconf automake gpg groff clang
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${LESS_TARBALL}
cd less-${LESS_VERSION}/
echo -e "${HOTPINK}= Generating files${NC}"
make -f Makefile.aut distfiles
echo -e "${PEACH}= Configure source${NC}"
./configure CC='clang' --with-regex=pcre2 --enable-year2038 --sysconfdir=/etc \
  --with-editor=/usr/bin/editor \
  LDFLAGS='${BLDFLAGS} ${MOLD} -no-pie' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fno-PIE'
echo -e "${VIOLET}= Building...${NC}"
CC='clang' make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "less" "./${CHROOTDIR}/less-${LESS_VERSION}/less"
