#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/common.sh"

setup_tools

echo -e "${VIOLET}= fetching latest upx version${NC}"
UPX_VERSION=$(gh_latest_release "upx/upx" '.tag_name | ltrimstr("v")') || true
if [ -z "${UPX_VERSION}" ]; then
  echo -e "${TAWNY}= GitHub API unavailable, falling back to upx 5.1.1${NC}"
  UPX_VERSION="5.1.1"
fi

PACKAGE_VERSION="${UPX_VERSION}"
UPX_TARBALL="upx-${UPX_VERSION}-src.tar.xz"
UPX_MIRRORS=(
  "https://github.com/upx/upx/releases/download/v${UPX_VERSION}/upx-${UPX_VERSION}-src.tar.xz"
  "https://fossies.org/linux/misc/upx-${UPX_VERSION}-src.tar.xz"
)

run_build_setup "upx" "${UPX_VERSION}" "${UPX_TARBALL}" \
  "upx-mod.patch" \
  -- "${UPX_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base ccache zlib-dev zlib-static zstd-dev zstd-static cmake samurai
apk upgrade musl-dev --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
chmod 755 upx
echo -e "${LIME}= Extracting source${NC}"
tar xf upx-${UPX_VERSION}-src.tar.xz
cd upx-${UPX_VERSION}-src/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../upx-mod.patch
sed -i 's|#define UPX_VERSION_HEX      0x050...|#define UPX_VERSION_HEX      0x050203|g' src/version.h
sed -i 's|05.01...|05.02.03|g' src/version.h
sed -i 's|"5...."|"5.2.3"|g' src/version.h
sed -i 's|"5..."|"5.23"|g' src/version.h
sed -i 's|#define UPX_VERSION_DATE     ".*|#define UPX_VERSION_DATE     "Mar 24th 2026"|g' src/version.h
sed -i 's|#define UPX_VERSION_DATE_ISO ".*|#define UPX_VERSION_DATE_ISO "2026-03-24"|g' src/version.h
mkdir build && cd build/
echo -e "${PEACH}= Configure source${NC}"
cmake -G Ninja \
  -DCMAKE_EXE_LINKER_FLAGS='-Wl,--gc-sections -static' \
  -DCMAKE_C_FLAGS_RELEASE='-Os  ${ARCH_FLAGS} -ffunction-sections -fdata-sections -fomit-frame-pointer -fno-stack-protector' \
  -DCMAKE_CXX_FLAGS_RELEASE='-Os  ${ARCH_FLAGS} -ffunction-sections -fdata-sections -fomit-frame-pointer -fno-stack-protector' \
  -DCMAKE_BUILD_TYPE=Release -DUPX_CONFIG_DISABLE_GITREV=ON -DUPX_CONFIG_DISABLE_WSTRICT=ON \
  -DUSE_STRICT_DEFAULTS=OFF -DUPX_CONFIG_REQUIRE_THREADS=ON -S ..
echo -e "${VIOLET}= Building...${NC}"
ninja -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip upx
cp upx upx1
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
./upx1 --lzma upx
EOF

package_output "upx" "./${CHROOTDIR}/upx-${UPX_VERSION}-src/build/upx"
