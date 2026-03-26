#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

setup_tools

SCREEN_VERSION="5.0.1"
PACKAGE_VERSION="${SCREEN_VERSION}"
SCREEN_TARBALL="screen-${SCREEN_VERSION}.tar.gz"
SCREEN_MIRRORS=(
  "https://ftp.gnu.org/gnu/screen/screen-${SCREEN_VERSION}.tar.gz"
  "https://fossies.org/linux/misc/screen-${SCREEN_VERSION}.tar.gz"
)

run_build_setup "screen" "${SCREEN_VERSION}" "${SCREEN_TARBALL}" \
  "screen-5.0.0-supress_remap.patch" \
  "screen-5.0.1-big-endian.patch" \
  -- "${SCREEN_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base ccache ncurses-dev ncurses-static openssl-dev openssl-libs-static
apk upgrade musl-dev --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
chmod 755 upx
echo -e "${LIME}= Extracting source${NC}"
tar xf ${SCREEN_TARBALL}
cd screen-${SCREEN_VERSION}/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../screen-5.0.0-supress_remap.patch
patch -p1 --fuzz=4 < ../screen-5.0.1-big-endian.patch
echo -e "${PEACH}= Configure source${NC}"
./configure CC=gcc --enable-telnet --with-pty-mode=0600  --enable-colors256 --enable-rxvt_osc --with-pty-group=5 \
  --enable-socket-dir=/run/screen --disable-pam --enable-utmp \
  LDFLAGS='${BASE_LDFLAGS}' PKG_CONFIG='${BASE_PKGCFG}' \
  CFLAGS='${BASE_CFLAGS} ${ARCH_FLAGS} -no-pie'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip screen
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
../upx --lzma screen
EOF

package_output "screen" "./${CHROOTDIR}/screen-${SCREEN_VERSION}/screen"
