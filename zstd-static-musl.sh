#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

echo -e "${VIOLET}= fetching latest zstd version${NC}"
ZSTD_VERSION=$(gh_latest_release "facebook/zstd" '.tag_name | ltrimstr("v")') || true
if [ -z "${ZSTD_VERSION}" ]; then
  echo -e "${TAWNY}= GitHub API unavailable, falling back to zstd 1.5.7${NC}"
  ZSTD_VERSION="1.5.7"
fi

PACKAGE_VERSION="${ZSTD_VERSION}"
ZSTD_TARBALL="zstd-${ZSTD_VERSION}.tar.zst"
ZSTD_MIRRORS=(
https://github.com/facebook/zstd/releases/download/v"${ZSTD_VERSION}"/zstd-"${ZSTD_VERSION}".tar.zst
https://www.paldo.org/paldo/sources/zstd/zstd-"${ZSTD_VERSION}".tar.zst
https://master.dl.sourceforge.net/project/zstandard.mirror/v"${ZSTD_VERSION}"/zstd-"${ZSTD_VERSION}".tar.zst
)

run_build_setup "zstd" "${ZSTD_VERSION}" "${ZSTD_TARBALL}" \
  "i486-no-cpuid.patch" \
  "zstd-1.5.6-gcc2.patch" \
  "zstd-1.5.6.patch" \
  -- "${ZSTD_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache lz4-dev lz4-static zlib-dev zlib-static xz-dev xz-static
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
7zz x -so ${ZSTD_TARBALL} | tar xf - -C /
cd zstd-${ZSTD_VERSION}/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../i486-no-cpuid.patch
patch -p1 --fuzz=4 < ../zstd-1.5.6-gcc2.patch
patch -p1 --fuzz=4 < ../zstd-1.5.6.patch
echo -e "${PEACH}= Configure source${NC}"
export LDFLAGS="${BLDFLAGS} ${MOLD} -static-libgcc -static-libstdc++ -no-pie"
export CFLAGS="${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -static-libgcc -static-libstdc++ -fno-PIE"
export HAVE_LZ4="1" HAVE_ZLIB="1" HAVE_LZMA="1"
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc) zstd-release
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip programs/zstd
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
upx --lzma programs/zstd
EOF

package_output "zstd" "./${CHROOTDIR}/zstd-${ZSTD_VERSION}/programs/zstd"
