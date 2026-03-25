#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

setup_tools

TAR_VERSION="1.35"
PACKAGE_VERSION="${TAR_VERSION}"
TAR_TARBALL="tar-${TAR_VERSION}.tar.xz"
TAR_MIRRORS=(
  "https://ftp.gnu.org/gnu/tar/tar-${TAR_VERSION}.tar.xz"
  "https://fossies.org/linux/misc/tar-${TAR_VERSION}.tar.xz"
  "https://mirrors.slackware.com/slackware/slackware64-current/source/a/tar/tar-${TAR_VERSION}.tar.xz"
  "https://mirrors.omnios.org/tar/tar-${TAR_VERSION}.tar.xz"
)

run_build_setup "tar" "${TAR_VERSION}" "${TAR_TARBALL}" \
  "tar.patch" \
  -- "${TAR_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base ccache automake autoconf pkgconfig zlib-dev zlib-static xz-dev xz-static zstd-dev zstd-static lz4-dev lz4-static libbz2 bzip2-static gettext-dev gettext-static
apk upgrade musl-dev --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
chmod 755 upx
echo -e "${LIME}= Extracting source${NC}"
tar xf tar-${TAR_VERSION}.tar.xz
cd tar-${TAR_VERSION}/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../tar.patch
autoreconf -f -i
echo -e "${PEACH}= Configure source${NC}"
FORCE_UNSAFE_CONFIGURE=1 ./configure CC=gcc \
  --without-selinux --disable-nls --disable-rpath --enable-largefile \
  LDFLAGS='-static -Wl,--gc-sections' PKG_CONFIG='pkg-config --static' \
  CFLAGS='-Os -static ${ARCH_FLAGS} -ffunction-sections -fdata-sections -fomit-frame-pointer -fno-stack-protector -no-pie'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip src/tar
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
../upx --lzma src/tar
EOF

package_output "tar" "./${CHROOTDIR}/tar-${TAR_VERSION}/src/tar"
