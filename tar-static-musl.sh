#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${MINT}= fetching latest tar version${NC}"
TAR_VERSION=$(get_web_version "https://ftp.gnu.org/gnu/tar/" "tar-\K[0-9]+\.[0-9]+(\.[0-9]+)?")
[[ -z "${TAR_VERSION}" ]] && { echo -e "${TAWNY}= ftp.gnu.org fetch failed, using fallback ${FALLBACK_TAR}${NC}" >&2; TAR_VERSION="${FALLBACK_TAR}"; }
echo -e "${JUNEBUD}= building tar version: ${TAR_VERSION}${NC}"
PACKAGE_VERSION="${TAR_VERSION}"
TAR_TARBALL="tar-${TAR_VERSION}.tar.xz"
TAR_MIRRORS=(
  "https://ftp.gnu.org/gnu/tar/tar-${TAR_VERSION}.tar.xz"
  "https://fossies.org/linux/misc/tar-${TAR_VERSION}.tar.xz"
  "https://mirrors.slackware.com/slackware/slackware64-current/source/a/tar/tar-${TAR_VERSION}.tar.xz"
  "https://mirrors.omnios.org/tar/tar-${TAR_VERSION}.tar.xz"
)

run_build_setup "tar" "${TAR_VERSION}" "${TAR_TARBALL}" \
  -- "${TAR_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache automake autoconf pkgconfig zlib-dev zlib-static xz-dev xz-static zstd-dev zstd-static lz4-dev \
  lz4-static libbz2 bzip2-static gettext-dev gettext-static texinfo linux-headers
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${TAR_TARBALL}
cd tar-${TAR_VERSION}/
if [ -d ../patches ]; then
   echo -e "${NEONPINK}= Applying custom patch(es)${NC}"
   for p in ../patches/*; do
       echo -e "${NEONBLUE}Applying \$(basename "\$p")...${NC}"
       patch -p1 --fuzz=4 < "\$p"
   done
fi
autoreconf -f -i
echo -e "${PEACH}= Configure source${NC}"
FORCE_UNSAFE_CONFIGURE=1 ./configure CC="${CC}" \
  --disable-nls --disable-rpath --enable-largefile --disable-silent-rules \
  --disable-gcc-warnings --without-selinux \
  LDFLAGS='${BLDFLAGS} ${MOLD} ${LNOPIE}' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CNOPIE}'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "tar" "./${CHROOTDIR}/tar-${TAR_VERSION}/src/tar"
