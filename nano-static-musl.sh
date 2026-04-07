#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${MINT}= fetching latest nano version${NC}"
NANO_VERSION=$(get_web_version "https://ftp.gnu.org/gnu/nano/" "nano-\K[0-9]+\.[0-9]+(\.[0-9]+)?")
[[ -z "${NANO_VERSION}" || "${NANO_VERSION}" == "FAILED" ]] && { echo -e "${TAWNY}= ftp.gnu.org fetch failed, using fallback ${FALLBACK_NANO}${NC}" >&2; NANO_VERSION="${FALLBACK_NANO}"; }
echo -e "${JUNEBUD}= building nano version: ${NANO_VERSION}${NC}"
PACKAGE_VERSION="${NANO_VERSION}"
NANO_TARBALL="nano-${NANO_VERSION}.tar.xz"
NANO_MIRRORS=(
  "https://www.nano-editor.org/dist/v8/nano-${NANO_VERSION}.tar.xz"
  "https://fossies.org/linux/misc/nano-${NANO_VERSION}.tar.xz"
  "https://gnu.mirror.constant.com/nano/nano-${NANO_VERSION}.tar.xz"
  "https://mirrors.slackware.com/slackware/slackware64-current/source/ap/nano/nano-${NANO_VERSION}.tar.xz"
)

run_build_setup "nano" "${NANO_VERSION}" "${NANO_TARBALL}" \
  -- "${NANO_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache pkgconfig ncurses-dev ncurses-static libmagic-static libmagic file-dev linux-headers
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${NANO_TARBALL}
cd nano-${NANO_VERSION}/
if [ -d ../patches ]; then
   echo -e "${NEONPINK}= Applying custom patch(es)${NC}"
   for p in ../patches/*; do
       echo -e "${NEONBLUE}Applying \$(basename "\$p")...${NC}"
       patch -p1 --fuzz=4 < "\$p"
   done
fi
echo -e "${PEACH}= Configure source${NC}"
./configure CC="${CC}" \
  --sysconfdir=/etc --disable-nls --disable-utf8 --disable-tiny --enable-nanorc --enable-color \
  --enable-extra --enable-largefile --enable-libmagic --disable-justify \
  LDFLAGS='${BLDFLAGS} ${MOLD} ${LNOPIE}' PKG_CONFIG='${PKGCFG}' CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CNOPIE}'
echo -e "${VIOLET}= Building...${NC}"
CC="${CC}" make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "nano" "./${CHROOTDIR}/nano-${NANO_VERSION}/src/nano"
