#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${VIOLET}= fetching latest axel version${NC}"
AXEL_VERSION=$(get_version release "axel-download-accelerator/axel" '.tag_name | ltrimstr("v")' "${FALLBACK_AXEL}")
echo -e "${MINT}= building axel version: ${AXEL_VERSION}${NC}"
PACKAGE_VERSION="${AXEL_VERSION}"
AXEL_TARBALL="axel-${AXEL_VERSION}.tar.xz"
AXEL_MIRRORS=(
  "https://github.com/axel-download-accelerator/axel/releases/download/v${AXEL_VERSION}/axel-${AXEL_VERSION}.tar.xz"
  "https://bos.us.distfiles.macports.org/axel/axel-${AXEL_VERSION}.tar.xz"
  "http://download.nus.edu.sg/mirror/gentoo/distfiles/d5/axel-${AXEL_VERSION}.tar.xz"
  "https://mse.uk.distfiles.macports.org/axel/axel-${AXEL_VERSION}.tar.xz"
  "https://mirror.ismdeep.com/axel/v${AXEL_VERSION}/axel-${AXEL_VERSION}.tar.xz"
  "https://code.opensuse.org/package/axel/blob/master/f/axel-${AXEL_VERSION}.tar.xz"
)

run_build_setup "axel" "${AXEL_VERSION}" "${AXEL_TARBALL}" \
  -- "${AXEL_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache openssl-dev zlib-dev libidn2-dev libpsl-dev libidn2-static openssl-libs-static zlib-static libpsl-static libunistring-dev libunistring-static
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${AXEL_TARBALL}
cd axel-${AXEL_VERSION}/
if [ -d ../patches ]; then
   # Check if directory is not empty
   if [ "\$(ls -A ../patches 2>/dev/null)" ]; then
       echo -e "${NEONPINK}= Applying custom patch(es)${NC}"
       for p in ../patches/*; do
           if [ -f "\$p" ]; then
               echo -e "${NEONBLUE}Applying \$(basename "\$p")...${NC}"
               patch -p1 --fuzz=4 < "\$p"
           fi
       done
   fi
fi
echo -e "${PEACH}= Configure source${NC}"
./configure CC="${CC}" \
  --disable-nls --enable-compile-warnings=no --disable-Werror \
  --with-ssl=openssl --enable-year2038 --disable-silent-rules \
  LDFLAGS='${BLDFLAGS} ${MOLD} ${LNOPIE}' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CNOPIE} -Wno-unterminated-string-initialization'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "axel" "./${CHROOTDIR}/axel-${AXEL_VERSION}/axel"
