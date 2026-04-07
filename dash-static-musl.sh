#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${MINT}= fetching latest dash version${NC}"
DASH_VERSION=$(get_git_version "https://git.kernel.org/pub/scm/utils/dash/dash.git/refs/tags" "v[0-9]+\.[0-9]+(\.[0-9]+)*" "v" "${FALLBACK_DASH}")
echo -e "${JUNEBUD}= building dash version: ${DASH_VERSION}${NC}"
PACKAGE_VERSION="${DASH_VERSION}"
DASH_TARBALL="dash-${DASH_VERSION}.tar.gz"
DASH_MIRRORS=(
  "https://git.kernel.org/pub/scm/utils/dash/dash.git/snapshot/dash-${DASH_VERSION}.tar.gz"
  "https://mirror-hk.koddos.net/blfs/svn/d/dash-${DASH_VERSION}.tar.gz"
  "https://mirror.freedif.org/pub/blfs/conglomeration/dash/dash-${DASH_VERSION}.tar.gz"
  "https://ftp.ec-m.fr/pub/OpenBSD/distfiles/dash-${DASH_VERSION}.tar.gz"
  "https://ftp.jaist.ac.jp/pub/Linux/Gentoo/distfiles/7a/dash-${DASH_VERSION}.tar.gz"
)

run_build_setup "dash" "${DASH_VERSION}" "${DASH_TARBALL}" \
  -- "${DASH_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache automake libtool bison flex pkgconfig readline-dev readline-static ncurses-dev ncurses-static autoconf patch libedit-dev libedit-static
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${DASH_TARBALL}
cd dash-${DASH_VERSION}/
if [ -d ../patches ]; then
   echo -e "${NEONPINK}= Applying custom patch(es)${NC}"
   for p in ../patches/*; do
       echo -e "${NEONBLUE}Applying \$(basename "\$p")...${NC}"
       patch -p1 --fuzz=4 < "\$p"
   done
fi
autoreconf -f -i
echo -e "${PEACH}= Configure source${NC}"
./configure --enable-static \
  LDFLAGS='${BLDFLAGS} ${MOLD} ${LPIE}' \
  PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CPIE} -fstack-clash-protection -Wno-maybe-uninitialized'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "dash" "./${CHROOTDIR}/dash-${DASH_VERSION}/src/dash"