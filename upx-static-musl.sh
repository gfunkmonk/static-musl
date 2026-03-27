#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/common.sh"

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
apk update && apk add build-base mold ccache zlib-dev zlib-static zstd-dev zstd-static cmake samurai
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${UPX_TARBALL}
cd upx-${UPX_VERSION}-src/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../upx-mod.patch
sed -i 's|define UPX_VERSION_HEX      0x050...|define UPX_VERSION_HEX      0x050103|g' src/version.h
sed -i 's|05.01...|05.01.03|g' src/version.h
sed -i 's|"5...."|"5.1.3"|g' src/version.h
sed -i 's|"5..."|"5.13"|g' src/version.h
sed -i "s/UPX_VERSION_DATE     \".*\"/UPX_VERSION_DATE     \"$(date +"%b %-d, %Y" | sed 's/\(1[0-9]\),/\1th,/;s/1,/1st,/;s/2,/2nd,/;s/3,/3rd,/;s/\([0-9]\),/\1th,/g' | sed 's/,//g')\"/g" src/version.h
sed -i "s/UPX_VERSION_DATE_ISO \".*\"/UPX_VERSION_DATE_ISO \"$(date '+%Y-%m-%d')\"/g" src/version.h
sed -i 's%UPX_VERSION_STRING "5.1.."%UPX_VERSION_STRING "5.1.3"%g' CMakeLists.txt
mkdir build && cd build/
echo -e "${PEACH}= Configure source${NC}"
cmake -G Ninja \
  -DCMAKE_EXE_LINKER_FLAGS='${BLDFLAGS} -static-pie -w -Wl,-s' \
  -DCMAKE_C_FLAGS_RELEASE='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fPIE' \
  -DCMAKE_CXX_FLAGS_RELEASE='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fPIE' \
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
