#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

setup_tools

DASH_VERSION="0.5.13.2"
PACKAGE_VERSION="${DASH_VERSION}"
DASH_TARBALL="dash-${DASH_VERSION}.tar.gz"
DASH_MIRRORS=(
  "https://git.kernel.org/pub/scm/utils/dash/dash.git/snapshot/dash-${DASH_VERSION}.tar.gz"
  #"http://gondor.apana.org.au/~herbert/dash/files/dash-${DASH_VERSION}.tar.gz"
  #"https://distfiles-origin.macports.org/dash/dash-${DASH_VERSION}.tar.gz"
  #"https://distfiles.alpinelinux.org/distfiles/v3.23/dash-${DASH_VERSION}.tar.gz"
  #"https://ftp.fr.openbsd.org/pub/OpenBSD/distfiles/dash-${DASH_VERSION}.tar.gz"
  #"https://mirror-hk.koddos.net/blfs/svn/d/dash-${DASH_VERSION}.tar.gz"
  #"https://mirrors.lug.mtu.edu/gentoo/distfiles/46/dash-${DASH_VERSION}.tar.gz"
)

run_build_setup "dash" "${DASH_VERSION}" "${DASH_TARBALL}" \
  "dash.patch" \
  "dash-cflags-for-build.patch" \
  "dash-SHELL-Disable-sh-c-command-sh-c-exec-command.patch" \
  -- "${DASH_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base ccache automake libtool bison flex pkgconfig readline-dev readline-static ncurses-dev ncurses-static autoconf patch libedit-dev libedit-static
apk upgrade musl-dev --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
chmod 755 upx
echo -e "${LIME}= Extracting source${NC}"
tar xf ${DASH_TARBALL}
cd dash-${DASH_VERSION}/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../dash.patch
patch -p1 --fuzz=4 < ../dash-cflags-for-build.patch
patch -p1 --fuzz=4 < ../dash-SHELL-Disable-sh-c-command-sh-c-exec-command.patch
autoreconf -f -i
echo -e "${PEACH}= Configure source${NC}"
./configure --enable-static \
  LDFLAGS='${BASE_LDFLAGS} -no-pie' \
  PKG_CONFIG='${BASE_PKGCFG}' \
  CFLAGS='${BASE_CFLAGS} ${ARCH_FLAGS} -fno-pie -fstack-clash-protection -Wno-maybe-uninitialized'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip src/dash
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
../upx --lzma src/dash
EOF

package_output "dash" "./${CHROOTDIR}/dash-${DASH_VERSION}/src/dash"
