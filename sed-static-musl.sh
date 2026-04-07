#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${MINT}= fetching latest sed version${NC}"
SED_VERSION=$(get_web_version "https://ftp.gnu.org/gnu/sed/" "sed-\K[0-9]+\.[0-9]+(\.[0-9]+)?")
[[ -z "${SED_VERSION}" || "${SED_VERSION}" == "FAILED" ]] && { echo -e "${TAWNY}= ftp.gnu.org fetch failed, using fallback ${FALLBACK_SED}${NC}" >&2; SED_VERSION="${FALLBACK_SED}"; }
echo -e "${JUNEBUD}= building sed version: ${SED_VERSION}${NC}"
PACKAGE_VERSION="${SED_VERSION}"
SED_TARBALL="sed-${SED_VERSION}.tar.xz"
SED_MIRRORS=(
  "https://ftp.gnu.org/gnu/sed/sed-${SED_VERSION}.tar.xz"
  "https://fossies.org/linux/misc/sed-${SED_VERSION}.tar.xz"
  "https://artfiles.org/gnu.org/sed/sed-${SED_VERSION}.tar.xz"
  "https://mirror.team-cymru.com/gnu/sed/sed-${SED_VERSION}.tar.xz"
)

run_build_setup "sed" "${SED_VERSION}" "${SED_TARBALL}" \
  -- "${SED_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache pkgconfig perl gettext-dev gettext-static
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${SED_TARBALL}
cd sed-${SED_VERSION}/
if [ -d ../patches ]; then
   echo -e "${NEONPINK}= Applying custom patch(es)${NC}"
   for p in ../patches/*; do
       echo -e "${NEONBLUE}Applying \$(basename "\$p")...${NC}"
       patch -p1 --fuzz=4 < "\$p"
   done
fi
echo -e "${PEACH}= Configure source${NC}"
./configure --enable-threads=posix --disable-nls --disable-i18n --disable-rpath \
  --disable-silent-rules --disable-gcc-warnings --without-selinux \
  LDFLAGS='${BLDFLAGS} ${MOLD} ${LNOPIE}' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CNOPIE}'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "sed" "./${CHROOTDIR}/sed-${SED_VERSION}/sed/sed"
