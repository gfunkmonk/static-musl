#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${VIOLET}= fetching latest htop version${NC}"
HTOP_VERSION=$(get_version release "htop-dev/htop" "" "${FALLBACK_HTOP}")
echo -e "${CORAL}= building htop version: ${HTOP_VERSION}${NC}"
PACKAGE_VERSION="${HTOP_VERSION}"
HTOP_TARBALL="htop-${HTOP_VERSION}.tar.xz"
HTOP_MIRRORS=(
  "https://github.com/htop-dev/htop/releases/download/${HTOP_VERSION}/htop-${HTOP_VERSION}.tar.xz"
  "https://fossies.org/linux/misc/htop-${HTOP_VERSION}.tar.xz"
  "https://gentoo.osuosl.org/distfiles/a5/htop-${HTOP_VERSION}.tar.xz"
  "https://sources.voidlinux.org/htop-${HTOP_VERSION}/htop-${HTOP_VERSION}.tar.xz"
)

run_build_setup "htop" "${HTOP_VERSION}" "${HTOP_TARBALL}" \
  -- "${HTOP_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache pkgconfig ncurses-dev \
  ncurses-static python3 lm-sensors-dev libnl3-dev libnl3-static linux-headers
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${HTOP_TARBALL}
cd htop-${HTOP_VERSION}/
if [ -d ../patches ]; then
   # Check if directory is not empty
   if [ "\$(ls -A ../patches 2>/dev/null)" ]; then
       echo -e "${NEONPINK}= Applying custom patch(es)${NC}"
       for p in ../patches/*; do
           if [ -f "\$p" ]; then
               echo -e "${NEONBLUE}Applying \$(basename "\$p")...${NC}"
               patch -p1 --fuzz=2 < "\$p"
           fi
       done
   fi
fi
echo -e "${PEACH}= Configure source${NC}"
./configure CC="${CC}" \
  --enable-unicode --enable-static --enable-affinity --enable-delayacct \
  LDFLAGS='${BLDFLAGS} ${MOLD} ${LNOPIE}' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CNOPIE}'
echo -e "${VIOLET}= Building...${NC}"
CC="${CC}" make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "htop" "./${CHROOTDIR}/htop-${HTOP_VERSION}/htop"
