#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

setup_tools

SED_VERSION="4.9"
PACKAGE_VERSION="${SED_VERSION}"
SED_SEDBALL="sed-${SED_VERSION}.tar.xz"
SED_MIRRORS=(
  "https://ftp.gnu.org/gnu/sed/sed-${SED_VERSION}.tar.xz"
  "https://fossies.org/linux/misc/sed-${SED_VERSION}.tar.xz"
)

run_build_setup "sed" "${SED_VERSION}" "${SED_SEDBALL}" \
  -- "${SED_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base musl-dev ccache pkgconfig perl gettext-dev gettext-static
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
chmod 755 upx
echo -e "${LIME}= Extracting source${NC}"
tar xf sed-${SED_VERSION}.tar.xz
cd sed-${SED_VERSION}/
echo -e "${PEACH}= Configure source${NC}"
./configure --enable-threads=posix --disable-nls --disable-i18n --disable-rpath \
  LDFLAGS='-static -Wl,--gc-sections' PKG_CONFIG='pkg-config --static' \
  CFLAGS='-Os -static ${ARCH_FLAGS} -ffunction-sections -fdata-sections -fomit-frame-pointer -fno-stack-protector -no-pie'
echo -e "${VIOLET}= Building...${NC}"
LDFLAGS='-static -Wl,--gc-sections' CFLAGS='-Os -static ${ARCH_FLAGS} -ffunction-sections -fdata-sections -fomit-frame-pointer -fno-stack-protector -no-pie' make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip sed/sed
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
../upx --lzma sed/sed
EOF

package_output "sed" "./${CHROOTDIR}/sed-${SED_VERSION}/sed/sed"
