#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${MINT}= fetching latest mc version${NC}"
MC_VERSION=$(get_version release "MidnightCommander/mc" '.tag_name | ltrimstr("v")' "${FALLBACK_MC}")
echo -e "${JUNEBUD}= building mc version: ${MC_VERSION}${NC}"
PACKAGE_VERSION="${MC_VERSION}"
MC_TARBALL="mc-${MC_VERSION}.tar.xz"
MC_MIRRORS=(
  "https://ftp.midnight-commander.org/mc-${MC_VERSION}.tar.xz"
  "https://github.com/MidnightCommander/mc/releases/download/${MC_VERSION}/mc-${MC_VERSION}.tar.xz"
  "https://fossies.org/linux/misc/mc-${MC_VERSION}.tar.xz"
)

run_build_setup "mc" "${MC_VERSION}" "${MC_TARBALL}" \
  -- "${MC_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache pkgconfig ncurses-dev ncurses-static \
  glib-dev glib-static pcre2-dev pcre2-static libffi-dev libffi-static \
  zlib-dev zlib-static linux-headers
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${MC_TARBALL}
cd mc-${MC_VERSION}/
echo -e "${PEACH}= Configure source${NC}"
./configure CC="${CC}" \
  --disable-nls --disable-tests --disable-doxygen-doc \
  --without-gnutls --without-mclib --without-x \
  --with-screen=ncurses --enable-charset \
  --disable-vfs-sftp --disable-vfs-undelfs \
  LDFLAGS='${BLDFLAGS} ${MOLD} -no-pie' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fno-PIE'
echo -e "${VIOLET}= Building...${NC}"
CC="${CC}" make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "mc" "./${CHROOTDIR}/mc-${MC_VERSION}/src/mc"
