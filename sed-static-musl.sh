#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

SED_VERSION="4.9"
PACKAGE_VERSION="${SED_VERSION}"
SED_TARBALL="sed-${SED_VERSION}.tar.xz"
SED_MIRRORS=(
  "https://ftp.gnu.org/gnu/sed/sed-${SED_VERSION}.tar.xz"
  "https://fossies.org/linux/misc/sed-${SED_VERSION}.tar.xz"
)

run_build_setup "sed" "${SED_VERSION}" "${SED_TARBALL}" \
  "sed-b-flag.patch" \
  "sed-c-flag.patch" \
  "sed-covscan-annotations.patch" \
  "sed-regexp-cache-size.patch" \
  -- "${SED_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base ccache pkgconfig perl gettext-dev gettext-static
apk upgrade musl-dev --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
chmod 755 upx
echo -e "${LIME}= Extracting source${NC}"
tar xf ${SED_TARBALL}
cd sed-${SED_VERSION}/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../sed-b-flag.patch
patch -p1 --fuzz=4 < ../sed-c-flag.patch
patch -p1 --fuzz=4 < ../sed-covscan-annotations.patch
patch -p1 --fuzz=4 < ../sed-regexp-cache-size.patch
echo -e "${PEACH}= Configure source${NC}"
./configure --enable-threads=posix --disable-nls --disable-i18n --disable-rpath \
  --disable-silent-rules --disable-gcc-warnings --without-selinux \
  LDFLAGS='${BASE_LDFLAGS} -static-pie -w -Wl,-s' PKG_CONFIG='${BASE_PKGCFG}' \
  CFLAGS='${BASE_CFLAGS} ${ARCH_FLAGS} ${EXTRA_CFLAGS} ${LTOFLAGS} -fPIE'
echo -e "${VIOLET}= Building...${NC}"
LDFLAGS='${BASE_LDFLAGS} -static-pie -w -Wl,-s' CFLAGS='${BASE_CFLAGS} ${ARCH_FLAGS} ${EXTRA_CFLAGS} ${LTOFLAGS} -fPIE' make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip sed/sed
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
../upx --lzma sed/sed
EOF

package_output "sed" "./${CHROOTDIR}/sed-${SED_VERSION}/sed/sed"
