#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${MINT}= fetching latest gawk version${NC}"
GAWK_VERSION=$(get_web_version "https://ftp.gnu.org/gnu/gawk/" "gawk-\K[0-9]+\.[0-9]+(\.[0-9]+)?")
[[ -z "${GAWK_VERSION}" || "${GAWK_VERSION}" == "FAILED" ]] && { echo -e "${TAWNY}= ftp.gnu.org fetch failed, using fallback ${FALLBACK_GAWK}${NC}" >&2; GAWK_VERSION="${FALLBACK_GAWK}"; }
echo -e "${JUNEBUD}= building gawk version: ${GAWK_VERSION}${NC}"
PACKAGE_VERSION="${GAWK_VERSION}"
GAWK_TARBALL="gawk-${GAWK_VERSION}.tar.xz"
GAWK_MIRRORS=(
  "https://ftp.gnu.org/gnu/gawk/gawk-${GAWK_VERSION}.tar.xz"
  "https://fossies.org/linux/misc/gawk-${GAWK_VERSION}.tar.xz"
  "https://mirror.us-midwest-1.nexcess.net/gnu/gawk/gawk-${GAWK_VERSION}.tar.xz"
)

run_build_setup "gawk" "${GAWK_VERSION}" "${GAWK_TARBALL}" \
  -- "${GAWK_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache pkgconfig bison readline-dev readline-static
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${GAWK_TARBALL}
cd gawk-${GAWK_VERSION}/
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
./configure --disable-nls --disable-rpath \
  LDFLAGS='${BLDFLAGS} ${MOLD} ${LNOPIE}' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CNOPIE}'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "gawk" "./${CHROOTDIR}/gawk-${GAWK_VERSION}/gawk"

