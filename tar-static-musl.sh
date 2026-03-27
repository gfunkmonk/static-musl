#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

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
  "tar-1.28-atime-rofs.patch" \
  "tar-1.28-vfatTruncate.patch" \
  "tar-1.29-wildcards.patch" \
  "tar-1.35-CVE-2025-45582.patch" \
  "tar-1.35-padding-zeros.patch" \
  "tar-1.35-revert-fix-savannah-bug-633567.patch" \
  "tar-oldgnu-unknown-mode-bits.patch" \
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
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../tar.patch
patch -p1 --fuzz=4 < ../tar-1.28-atime-rofs.patch
patch -p1 --fuzz=4 < ../tar-1.28-vfatTruncate.patch
patch -p1 --fuzz=4 < ../tar-1.29-wildcards.patch
patch -p1 --fuzz=4 < ../tar-1.35-CVE-2025-45582.patch
patch -p1 --fuzz=4 < ../tar-1.35-padding-zeros.patch
patch -p1 --fuzz=4 < ../tar-1.35-revert-fix-savannah-bug-633567.patch
patch -p1 --fuzz=4 < ../tar-oldgnu-unknown-mode-bits.patch
autoreconf -f -i
echo -e "${PEACH}= Configure source${NC}"
FORCE_UNSAFE_CONFIGURE=1 ./configure CC=gcc \
  --disable-nls --disable-rpath --enable-largefile --disable-silent-rules \
  --disable-gcc-warnings --without-selinux \
  LDFLAGS='${BLDFLAGS} ${MOLD} -no-pie -w -Wl,-s' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fno-PIE'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip src/tar
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
upx --lzma src/tar
EOF

package_output "tar" "./${CHROOTDIR}/tar-${TAR_VERSION}/src/tar"
