#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

setup_tools

echo -e "${VIOLET}= fetching latest less version${NC}"
LESS_VERSION=$(gh_latest_tag "gwsw/less" '.[0].name | ltrimstr("v")') || true
if [ -z "${LESS_VERSION}" ]; then
  echo -e "${TAWNY}= GitHub API unavailable, falling back to less 692${NC}"
  LESS_VERSION="692"
fi

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
apk update && apk add build-base ccache pkgconfig pcre2-static pcre2-dev ncurses-dev \
  ncurses-static perl autoconf automake gpg groff clang
apk upgrade musl-dev --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
chmod 755 upx
echo -e "${LIME}= Extracting source${NC}"
tar xf ${LESS_TARBALL}
cd less-${LESS_VERSION}/
echo -e "${HOTPINK}= Generating files${NC}"
make -f Makefile.aut distfiles
echo -e "${PEACH}= Configure source${NC}"
./configure CC=clang --with-regex=pcre2 --enable-year2038 --sysconfdir=/etc \
  --with-editor=/usr/bin/editor \
  LDFLAGS='${BASE_LDFLAGS}' PKG_CONFIG='${BASE_PKGCFG}' \
  CFLAGS='${BASE_CFLAGS} ${ARCH_FLAGS}'
echo -e "${VIOLET}= Building...${NC}"
CC=clang make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip less
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
../upx --lzma less
EOF

package_output "less" "./${CHROOTDIR}/less-${LESS_VERSION}/less"
