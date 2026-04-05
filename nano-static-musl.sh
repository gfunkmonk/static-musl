#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${MINT}= fetching latest nano version${NC}"
NANO_VERSION=$(get_git_version "https://cgit.git.savannah.gnu.org/cgit/nano.git/refs/tags" "v[0-9]+\.[0-9]+(\.[0-9]+)*" "v" "${FALLBACK_NANO}")
echo -e "${JUNEBUD}= building nano version: ${NANO_VERSION}${NC}"
PACKAGE_VERSION="${NANO_VERSION}"
NANO_TARBALL="nano-${NANO_VERSION}.tar.xz"
NANO_MIRRORS=(
  "https://www.nano-editor.org/dist/v8/nano-${NANO_VERSION}.tar.xz"
  "https://fossies.org/linux/misc/nano-${NANO_VERSION}.tar.xz"
)

run_build_setup "nano" "${NANO_VERSION}" "${NANO_TARBALL}" \
  "nano-colors.patch" \
  -- "${NANO_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache pkgconfig ncurses-dev ncurses-static libmagic-static libmagic file-dev linux-headers
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${NANO_TARBALL}
cd nano-${NANO_VERSION}/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../nano-colors.patch
echo -e "${PEACH}= Configure source${NC}"
./configure CC="${CC}" \
  --sysconfdir=/etc --disable-nls --disable-utf8 --disable-tiny --enable-nanorc --enable-color \
  --enable-extra --enable-largefile --enable-libmagic --disable-justify \
  LDFLAGS='${BLDFLAGS} ${MOLD} -no-pie' PKG_CONFIG='${PKGCFG}' CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fno-PIE'
echo -e "${VIOLET}= Building...${NC}"
CC="${CC}" make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "nano" "./${CHROOTDIR}/nano-${NANO_VERSION}/src/nano"
