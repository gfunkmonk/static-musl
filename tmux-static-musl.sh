#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

echo -e "${VIOLET}= fetching latest tmux version${NC}"
TMUX_VERSION=$(get_version release "tmux/tmux" ".tag_name" "3.6")
echo -e "${PEACH}= building tmux version: ${TMUX_VERSION}${NC}"
PACKAGE_VERSION="${TMUX_VERSION}"
TMUX_TARBALL="tmux-${TMUX_VERSION}.tar.gz"
TMUX_MIRRORS=(
  "https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/tmux-${TMUX_VERSION}.tar.gz"
  "https://fossies.org/linux/misc/tmux-${TMUX_VERSION}.tar.gz"
  "https://sources.voidlinux.org/tmux-${TMUX_VERSION}/tmux-${TMUX_VERSION}.tar.gz"
)

run_build_setup "tmux" "${TMUX_VERSION}" "${TMUX_TARBALL}" \
  "platform-quirks.patch" \
  -- "${TMUX_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache ncurses-dev ncurses-static libevent-static libevent-dev libsixel-dev bison \
  pkgconf jemalloc-static jemalloc-dev
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${TURQUOISE}= Download & build libutempter..${NC}"
/usr/local/bin/curl --output libutempter-1.2.1.tar.gz https://ftp.altlinux.org/pub/people/ldv/utempter/libutempter-1.2.1.tar.gz
tar xvfz libutempter-1.2.1.tar.gz
cd libutempter-1.2.1/
echo -e "${UGLY}= Installing libutempter${NC}"
make && make install
cd ../
echo -e "${LIME}= Extracting source${NC}"
tar xf ${TMUX_TARBALL}
cd tmux-${TMUX_VERSION}/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../platform-quirks.patch
echo -e "${PEACH}= Configure source${NC}"
./configure CC=gcc \
  --enable-static --enable-sixel --enable-utempter --enable-jemalloc \
  LDFLAGS='${BLDFLAGS} ${MOLD} -no-pie' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fno-PIE'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip tmux
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
upx --lzma tmux
EOF

package_output "tmux" "./${CHROOTDIR}/tmux-${TMUX_VERSION}/tmux"
