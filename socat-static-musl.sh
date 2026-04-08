#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${MINT}= fetching latest socat version${NC}"
#SOCAT_VERSION=$(get_git_version "https://repo.or.cz/socat.git/refs/tags" "tag-1\.[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)*" "tag-" "${FALLBACK_SOCAT}")
SOCAT_VERSION=$(get_web_version "http://www.dest-unreach.org/socat/download/" "socat-\K1\.[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)*")
[[ -z "${SOCAT_VERSION}" || "${SOCAT_VERSION}" == "FAILED" ]] && { echo -e "${TAWNY}= socat source fetch failed, using fallback ${FALLBACK_SOCAT}${NC}" >&2; SOCAT_VERSION="${FALLBACK_SOCAT}"; }
echo -e "${JUNEBUD}= building socat version: ${SOCAT_VERSION}${NC}"
PACKAGE_VERSION="${SOCAT_VERSION}"
SOCAT_TARBALL="socat-${SOCAT_VERSION}.tar.gz"
SOCAT_MIRRORS=(
  "http://www.dest-unreach.org/socat/download/socat-${SOCAT_VERSION}.tar.gz"
  "https://fossies.org/linux/privat/socat-${SOCAT_VERSION}.tar.gz"
  "https://distfiles.alpinelinux.org/distfiles/edge/socat-${SOCAT_VERSION}.tar.gz"
)

run_build_setup "socat" "${SOCAT_VERSION}" "${SOCAT_TARBALL}" \
  -- "${SOCAT_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache pkgconfig openssl-dev openssl-libs-static readline-dev readline-static ncurses-dev \
  ncurses-static ncurses-terminfo-base linux-headers tar
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${SOCAT_TARBALL}
cd socat-${SOCAT_VERSION}/
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
./configure --enable-openssl --disable-ip6 --enable-readline --enable-largefile --enable-default-ipv=4 \
  LDFLAGS='${BLDFLAGS} ${MOLD} ${LNOPIE}' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CNOPIE}'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "socat" "./${CHROOTDIR}/socat-${SOCAT_VERSION}/socat"
