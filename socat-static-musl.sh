#!/bin/bash
set -euo pipefail
. $(dirname "${BASH_SOURCE[0]}")/common.sh

SOCAT_VERSION="1.8.1.1"
PACKAGE_VERSION="${SOCAT_VERSION}"
SOCAT_TARBALL="socat-${SOCAT_VERSION}.tar.gz"
SOCAT_MIRRORS=(
  "http://www.dest-unreach.org/socat/download/socat-${SOCAT_VERSION}.tar.gz"
  "https://fossies.org/linux/privat/socat-${SOCAT_VERSION}.tar.gz"
  "https://distfiles.alpinelinux.org/distfiles/edge/socat-${SOCAT_VERSION}.tar.gz"
)

run_build_setup "socat" "${SOCAT_VERSION}" "${SOCAT_TARBALL}" \
  "hotfix-const-correctness.patch" \
  -- "${SOCAT_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache pkgconfig openssl-dev openssl-libs-static readline-dev readline-static ncurses-dev \
  ncurses-static ncurses-terminfo-base linux-headers tar
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${SOCAT_TARBALL}
cd socat-${SOCAT_VERSION}/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../hotfix-const-correctness.patch
echo -e "${PEACH}= Configure source${NC}"
./configure --enable-openssl --disable-ip6 --enable-readline --enable-largefile --enable-default-ipv=4 \
  LDFLAGS='${BLDFLAGS} ${MOLD} -no-pie -w -Wl,-s' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fno-PIE'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip socat
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
upx --lzma socat
EOF

package_output "socat" "./${CHROOTDIR}/socat-${SOCAT_VERSION}/socat"
