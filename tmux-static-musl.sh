#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${VIOLET}= fetching latest tmux version${NC}"
TMUX_VERSION=$(get_version release "tmux/tmux" ".tag_name" "${FALLBACK_TMUX}")
echo -e "${PEACH}= building tmux version: ${TMUX_VERSION}${NC}"
PACKAGE_VERSION="${TMUX_VERSION}"
TMUX_TARBALL="tmux-${TMUX_VERSION}.tar.gz"
TMUX_MIRRORS=(
  "https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/tmux-${TMUX_VERSION}.tar.gz"
  "https://fossies.org/linux/misc/tmux-${TMUX_VERSION}.tar.gz"
  "https://sources.voidlinux.org/tmux-${TMUX_VERSION}/tmux-${TMUX_VERSION}.tar.gz"
)

UTEMPTER_VERSION="1.2.1"
UTEMPTER_TARBALL="libutempter-${UTEMPTER_VERSION}.tar.gz"
UTEMPTER_MIRRORS=(
  "https://ftp.altlinux.org/pub/people/ldv/utempter/libutempter-${UTEMPTER_VERSION}.tar.gz"
  "http://mirrors.redcorelinux.org/redcorelinux/amd64/distfiles-next/libutempter-${UTEMPTER_VERSION}.tar.gz"
  "https://hina.lysator.liu.se/pub/void-ppc-sources/libutempter-${UTEMPTER_VERSION}/libutempter-${UTEMPTER_VERSION}.tar.gz"
)

download_source "libutempter" "${UTEMPTER_VERSION}" "${UTEMPTER_TARBALL}" "${UTEMPTER_MIRRORS[@]}"

run_build_setup "tmux" "${TMUX_VERSION}" "${TMUX_TARBALL}" \
  "platform-quirks.patch" \
  -- "${TMUX_MIRRORS[@]}"

cp distfiles/"${UTEMPTER_TARBALL}" "./${CHROOTDIR}/${UTEMPTER_TARBALL}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache ncurses-dev ncurses-static libevent-static libevent-dev libsixel-dev bison \
  pkgconf jemalloc-static jemalloc-dev
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${TURQUOISE}= Extract libutempter..${NC}"
tar xvfz ${UTEMPTER_TARBALL}
cd libutempter-${UTEMPTER_VERSION}/
echo -e "${UGLY}= Installing libutempter${NC}"
make && make install
cd ../
echo -e "${LIME}= Extracting source${NC}"
tar xf ${TMUX_TARBALL}
cd tmux-${TMUX_VERSION}/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../platform-quirks.patch
echo -e "${PEACH}= Configure source${NC}"
./configure CC="${CC}" \
  --enable-static --enable-sixel --enable-utempter --enable-jemalloc \
  LDFLAGS='${BLDFLAGS} ${MOLD} -no-pie' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fno-PIE'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "tmux" "./${CHROOTDIR}/tmux-${TMUX_VERSION}/tmux"
