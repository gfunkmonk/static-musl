#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

echo -e "${VIOLET}= fetching latest oksh version${NC}"
OKSH_VERSION=$(get_version release "ibara/oksh" ".tag_name | ltrimstr("oksh-")" "7.8")

PACKAGE_VERSION="${OKSH_VERSION}"
OKSH_TARBALL="oksh-${OKSH_VERSION}.tar.gz"
OKSH_MIRRORS=(
  "https://github.com/ibara/oksh/releases/download/oksh-${OKSH_VERSION}/oksh-${OKSH_VERSION}.tar.gz"
  "https://distfiles.alpinelinux.org/distfiles/v3.23/oksh-${OKSH_VERSION}.tar.gz"
)

run_build_setup "oksh" "${OKSH_VERSION}" "${OKSH_TARBALL}" \
  -- "${OKSH_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache pkgconfig ncurses-dev ncurses-static clang
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${OKSH_TARBALL}
cd oksh-${OKSH_VERSION}/
echo -e "${PEACH}= Configure source${NC}"
./configure --cc=clang --cflags="${BCFLAGS} ${ARCH_FLAGS} ${EXTRA}" \
  --enable-curses --enable-static --enable-lto \
  LDFLAGS='${BLDFLAGS} ${MOLD}' PKG_CONFIG='${PKGCFG}'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip oksh
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
upx --lzma oksh
EOF

package_output "oksh" "./${CHROOTDIR}/oksh-${OKSH_VERSION}/oksh"
