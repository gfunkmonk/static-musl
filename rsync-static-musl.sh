#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${LEMON}= fetching latest rsync version${NC}"
RSYNC_VERSION=$(get_version release "RsyncProject/rsync" '.tag_name | ltrimstr("v")' "${FALLBACK_RSYNC}")
echo -e "${LAGOON}= building rsync version: ${RSYNC_VERSION}${NC}"
PACKAGE_VERSION="${RSYNC_VERSION}"
RSYNC_TARBALL="rsync-${RSYNC_VERSION}.tar.gz"
RSYNC_MIRRORS=(
  "https://github.com/RsyncProject/rsync/releases/download/v${RSYNC_VERSION}/rsync-${RSYNC_VERSION}.tar.gz"
  "https://rsync.samba.org/ftp/rsync/rsync-${RSYNC_VERSION}.tar.gz"
  "https://ftp2.osuosl.org/pub/blfs/conglomeration/rsync/rsync-${RSYNC_VERSION}.tar.gz"
)

run_build_setup "rsync" "${RSYNC_VERSION}" "${RSYNC_TARBALL}" \
  -- "${RSYNC_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold pkgconfig clang acl-dev acl-static attr-dev zstd-dev zstd-static openssl-libs-static openssl-dev git lz4-dev xxhash-dev
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
echo -e "${CANARY}= Build & install xxHash${NC}"
git clone https://github.com/Cyan4973/xxHash.git
cd xxHash
PREFIX=/usr CC="${CC}" make LDFLAGS='${BLDFLAGS} ${MOLD} ${LPIE}' PKG_CONFIG='${PKGCFG}' CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CPIE}'
PREFIX=/usr CC="${CC}" make install LDFLAGS='${BLDFLAGS} ${MOLD} ${LPIE}' PKG_CONFIG='${PKGCFG}' CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CPIE}'
cd ..
echo -e "${REBECCA}= Build & install lz4${NC}"
git clone https://github.com/lz4/lz4.git
cd lz4
PREFIX=/usr CC="${CC}" make LDFLAGS='${BLDFLAGS} ${MOLD} ${LPIE}' PKG_CONFIG='${PKGCFG}' CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CPIE}'
PREFIX=/usr CC="${CC}" make install LDFLAGS='${BLDFLAGS} ${MOLD} ${LPIE}' PKG_CONFIG='${PKGCFG}' CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CPIE}'
cd ..
# mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${RSYNC_TARBALL}
cd rsync-${RSYNC_VERSION}/
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
./configure CC="${CC}" --disable-ipv6 --disable-roll-simd --with-included-zlib=no --disable-md5-asm \
  LDFLAGS='${BLDFLAGS} ${MOLD} ${LPIE}' PKG_CONFIG='${PKGCFG}' EXEEXT='-static' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CPIE} -Wno-maybe-uninitialized -Wno-unused-variable -Wno-unused-parameter \
  -Wno-calloc-transposed-args -Wno-unused-but-set-variable -Wno-old-style-definition'
echo -e "${VIOLET}= Building...${NC}"
CC="${CC}" make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "rsync" "./${CHROOTDIR}/rsync-${RSYNC_VERSION}/rsync"
