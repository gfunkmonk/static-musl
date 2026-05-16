#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${MINT}= fetching latest mc version${NC}"
MC_VERSION=$(get_web_version "https://ftp.osuosl.org/pub/midnightcommander/" "mc-\K[0-9]+\.[0-9]+(\.[0-9]+)?")
[[ -z "${MC_VERSION}" || "${MC_VERSION}" == "FAILED" ]] && { echo -e "${TAWNY}= mc source fetch failed, using fallback ${FALLBACK_MC}${NC}" >&2; MC_VERSION="${FALLBACK_MC}"; }
echo -e "${JUNEBUD}= building mc version: ${MC_VERSION}${NC}"
PACKAGE_VERSION="${MC_VERSION}"
MC_TARBALL="mc-${MC_VERSION}.tar.xz"
MC_MIRRORS=(
  "https://ftp.osuosl.org/pub/midnightcommander/mc-${MC_VERSION}.tar.xz"
  "https://fossies.org/linux/misc/mc-${MC_VERSION}.tar.xz"
  "https://mirrors.mit.edu/macports/distfiles/mc/mc-${MC_VERSION}.tar.xz"
)
run_build_setup "mc" "${MC_VERSION}" "${MC_TARBALL}" \
  -- "${MC_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache pkgconfig ncurses-dev ncurses-static glib-dev glib-static pcre2-dev \
  pcre2-static libffi-dev zlib-dev zlib-static linux-headers slang-dev slang-static libedit-dev libedit-static
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${MC_TARBALL}
cd mc-${MC_VERSION}/
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
  --disable-nls --disable-tests --disable-doxygen-doc --without-gnutls --without-mclib \
  --without-x --enable-charset --disable-vfs-sftp --disable-vfs-undelfs --enable-static \
  --disable-shared --prefix=/usr --sysconfdir=/etc --libexecdir=/usr/lib \
  LDFLAGS='${BLDFLAGS} ${MOLD} ${LNOPIE}' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CNOPIE}'
echo -e "${VIOLET}= Building...${NC}"
CC="${CC}" make -j\$(nproc) LDFLAGS='-all-static ${BLDFLAGS} ${MOLD} ${LNOPIE}'
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "mc" "./${CHROOTDIR}/mc-${MC_VERSION}/src/mc"