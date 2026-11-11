#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${AQUA}= fetching latest zstd version${NC}"
ZSTD_VERSION=$(get_version release "facebook/zstd" '.tag_name | ltrimstr("v")' "${FALLBACK_ZSTD}")
echo -e "${BOYSENBERRY}= building zstd version: ${ZSTD_VERSION}${NC}"
PACKAGE_VERSION="${ZSTD_VERSION}"
ZSTD_TARBALL="zstd-${ZSTD_VERSION}.tar.zst"
ZSTD_MIRRORS=(
  "https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/zstd-${ZSTD_VERSION}.tar.zst"
  "https://www.paldo.org/paldo/sources/zstd/zstd-${ZSTD_VERSION}.tar.zst"
)

run_build_setup "zstd" "${ZSTD_VERSION}" "${ZSTD_TARBALL}" \
  -- "${ZSTD_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache lz4-dev lz4-static zlib-dev zlib-static xz-dev xz-static
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
7zz x -so ${ZSTD_TARBALL} | tar xf -
cd zstd-${ZSTD_VERSION}/
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
export LDFLAGS="${BLDFLAGS} ${MOLD} ${LNOPIE} -static-libgcc -static-libstdc++ "
export CFLAGS="${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CNOPIE} -static-libgcc -static-libstdc++ "
export HAVE_LZ4="1" HAVE_ZLIB="1" HAVE_LZMA="1"
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc) zstd-release
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "zstd" "./${CHROOTDIR}/zstd-${ZSTD_VERSION}/programs/zstd"
