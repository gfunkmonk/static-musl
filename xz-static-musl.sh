#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${SKY}= fetching latest xz version${NC}"
XZ_VERSION=$(get_version release "tukaani-project/xz" '.tag_name | ltrimstr("v")' "${FALLBACK_XZ}")
echo -e "${TAWNY}= building xz version: ${XZ_VERSION}${NC}"
PACKAGE_VERSION="${XZ_VERSION}"
XZ_TARBALL="xz-${XZ_VERSION}.tar.xz"
XZ_MIRRORS=(
  "https://github.com/tukaani-project/xz/releases/download/v${XZ_VERSION}/xz-${XZ_VERSION}.tar.xz"
  "https://netactuate.dl.sourceforge.net/project/lzmautils/xz-${XZ_VERSION}.tar.xz"
  "https://www.mirrorservice.org/pub/slackware/slackware-current/source/a/xz/xz-${XZ_VERSION}.tar.xz"
  "https://m3-container.net/M3_Container/oss_packages/xz-${XZ_VERSION}.tar.xz"
)

run_build_setup "xz" "${XZ_VERSION}" "${XZ_TARBALL}" \
  -- "${XZ_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache clang autoconf automake libtool gettext-dev gettext-static
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${XZ_TARBALL}
cd xz-${XZ_VERSION}/
echo -e "${PEACH}= Configure source${NC}"
./configure CC='clang' --enable-static --disable-shared --disable-nls --enable-small \
  --enable-threads=yes --disable-silent-rules --disable-rpath --enable-lzip-decoder \
  --enable-year2038 --enable-largefile \
  LDFLAGS='${BLDFLAGS} ${MOLD} ${LPIE}' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CPIE} -Wno-unterminated-string-initialization'
echo -e "${VIOLET}= Building...${NC}"
CC='clang' make -j\$(nproc) V=1 LDFLAGS='-all-static ${BLDFLAGS} ${MOLD} ${LPIE}'
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "xz" "./${CHROOTDIR}/xz-${XZ_VERSION}/src/xz/xz"
