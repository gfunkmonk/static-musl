#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/common.sh"

echo -e "${VIOLET}= fetching latest 7zip version${NC}"
SEVENZIP_VERSION=$(gh_latest_release "mcmilk/7-Zip-zstd") || true
if [ -z "${SEVENZIP_VERSION}" ]; then
  echo -e "${TAWNY}= GitHub API unavailable, falling back to v25.01-v1.5.7-R4${NC}"
  SEVENZIP_VERSION="v25.01-v1.5.7-R4"
fi

PACKAGE_VERSION="${SEVENZIP_VERSION}"
SEVENZIP_SHORT="${SEVENZIP_VERSION#v}"
SEVENZIP_TARBALL="7-Zip-zstd-${SEVENZIP_VERSION}.tar.gz"
SEVENZIP_MIRRORS=(
  "https://github.com/mcmilk/7-Zip-zstd/archive/refs/tags/${SEVENZIP_VERSION}.tar.gz"
)

run_build_setup "7zz" "${SEVENZIP_VERSION}" "${SEVENZIP_TARBALL}" \
  "7z-0003-Disable-local-echo-display-when-in-input-passwords-C.patch" \
  "7z-0004-Use-system-locale-to-select-codepage-for-legacy-zip-.patch" \
  "7z-0005-Fix-BROTLI_MODEL-attribute-for-loongarch64.patch" \
  -- "${SEVENZIP_MIRRORS[@]}"

# Map repo ARCH to 7zip Linux makefile; source extracts flat so we wrap in a versioned dir
case "${ARCH}" in
  x86_64|x86-64|amd64)
     MAKE_OPTS="MY_ASM=/usr/bin/uasm -f ../../cmpl_gcc.mak 7z_asm=uasm"
     PLATFORM="x64"
     ARCH_FLAGS="-march=x86-64 -mtune=generic"
     ;;
  x86|i*86)
     MAKE_OPTS="MY_ASM=/usr/bin/uasm -f ../../cmpl_gcc.mak 7z_asm=uasm"
     PLATFORM="x86"
     ARCH_FLAGS="-march=i586 -mtune=generic"
     ;;
  aarch64|arm64|armv8)
     MAKE_OPTS="-f ../../cmpl_gcc_arm64.mak"
     PLATFORM="arm64"
     ARCH_FLAGS="-march=armv8-a"
     ;;
  armv7|armv7l)
     MAKE_OPTS="-f ../../cmpl_gcc_arm.mak"
     PLATFORM="arm"
     ARCH_FLAGS="-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard -marm -Wno-sign-conversion -Wno-implicit-fallthrough -Wno-unused-macros"
     ;;
  armhf|armv6|arm)
     MAKE_OPTS="-f ../../cmpl_gcc_arm.mak"
     PLATFORM="arm"
     ARCH_FLAGS="-march=armv6kz -mfloat-abi=hard -mfpu=vfp"
     ;;
  *)
     MAKE_OPTS="-f ../../cmpl_gcc.mak"
     PLATFORM=""
     ARCH_FLAGS=""
     ;;
esac

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache gcc g++ patch git nasm make
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
apk add uasm --repository=https://dl-cdn.alpinelinux.org/alpine/edge/testing
mkdir -p /ccache
export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${SEVENZIP_TARBALL}
cd 7-Zip-zstd-${SEVENZIP_SHORT}/
echo -e "${LAGOON}= Applying custom patches${NC}"
patch -p1 --fuzz=4 < ../7z-0003-Disable-local-echo-display-when-in-input-passwords-C.patch
patch -p1 --fuzz=4 < ../7z-0004-Use-system-locale-to-select-codepage-for-legacy-zip-.patch
patch -p1 --fuzz=4 < ../7z-0005-Fix-BROTLI_MODEL-attribute-for-loongarch64.patch
sed -i 's/CFLAGS_BASE = -O2/CFLAGS_BASE = ${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fPIE -Wno-sign-conversion/g' CPP/7zip/7zip_gcc.mak
sed -i 's/LDFLAGS = -Wall/LDFLAGS = ${BLDFLAGS} -w -Wl,-s -static-pie/g' CPP/7zip/7zip_gcc.mak
cd CPP/7zip/Bundles/Alone2
mkdir -p b/g
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc) \
  CFLAGS_BASE_LIST='-c -D_7ZIP_AFFINITY_DISABLE=1 -DZ7_AFFINITY_DISABLE=1 -D_GNU_SOURCE=1' \
  CFLAGS_WARN_WALL='-Wall -Wextra' ${MAKE_OPTS} PLATFORM=${PLATFORM} COMPL_STATIC=1 \
  CC='gcc ${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fPIE -Wno-sign-conversion' \
  CXX='g++ ${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fPIE -Wno-sign-conversion'
binary=\$(find . \( -name '7zzs' -o -name '7zz' \) -type f | head -n1)
[ -n "\$binary" ] || { echo "Error: 7zzs or 7zz binary not found after build" >&2; exit 1; }
cp -va "\$binary" 7zz
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip 7zz
cp 7zz /7-Zip-zstd-${SEVENZIP_SHORT}/7zz
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
upx --lzma /7-Zip-zstd-${SEVENZIP_SHORT}/7zz
EOF

package_output "7zz" "./${CHROOTDIR}/7-Zip-zstd-${SEVENZIP_SHORT}/7zz"
