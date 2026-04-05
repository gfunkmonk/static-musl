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
)

run_build_setup "rsync" "${RSYNC_VERSION}" "${RSYNC_TARBALL}" \
  -- "${RSYNC_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache pkgconfig clang acl-dev acl-static attr-dev zstd-dev zstd-static openssl-libs-static \
  openssl-dev lz4-dev lz4-static git
apk add xxhash-dev xxhash-static --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
apk upgrade musl-dev mold xxhash-dev xxhash-static --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${CANARY}= Build & install xxHash${NC}"
git clone https://github.com/Cyan4973/xxHash.git
cd xxHash
CCACHE_DISABLE=1 PREFIX=/usr CC=/usr/bin/clang make LDFLAGS='-static' PKG_CONFIG='pkg-config --static' CFLAGS='-Os -static'
CCACHE_DISABLE=1 PREFIX=/usr CC=/usr/bin/clang make install LDFLAGS='-static' PKG_CONFIG='pkg-config --static' CFLAGS='-Os -static'
cd ..
echo -e "${REBECCA}= Build & install lz4${NC}"
git clone https://github.com/lz4/lz4.git
cd lz4
CCACHE_DISABLE=1 PREFIX=/usr CC=/usr/bin/clang make LDFLAGS='-static' PKG_CONFIG='pkg-config --static' CFLAGS='-Os -static'
CCACHE_DISABLE=1 PREFIX=/usr CC=/usr/bin/clang make install LDFLAGS='-static' PKG_CONFIG='pkg-config --static' CFLAGS='-Os -static'
cd ..
echo -e "${LIME}= Extracting source${NC}"
tar xf ${RSYNC_TARBALL}
cd rsync-${RSYNC_VERSION}/
echo -e "${PEACH}= Configure source${NC}"
CCACHE_DISABLE=1 ./configure CC=/usr/bin/clang --disable-ipv6 \
  LDFLAGS='-static' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='-Os -static' LD_LIBRARY_PATH='/lib:/usr/lib:/usr/local/lib' EXEEXT="-static"
echo -e "${VIOLET}= Building...${NC}"
CCACHE_DISABLE=1 CC=clang make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "rsync" "./${CHROOTDIR}/rsync-${RSYNC_VERSION}/rsync"
