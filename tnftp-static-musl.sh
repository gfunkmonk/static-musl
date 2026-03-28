#!/bin/bash
set -euo pipefail
. $(dirname "${BASH_SOURCE[0]}")/common.sh

TNFTP_VERSION="20260211"
PACKAGE_VERSION="${TNFTP_VERSION}"
TNFTP_TARBALL="tnftp-${TNFTP_VERSION}.tar.gz"
TNFTP_MIRRORS=(
  "ftp://ftp.netbsd.org/pub/NetBSD/misc/tnftp/tnftp-${TNFTP_VERSION}.tar.gz"
  "https://fossies.org/linux/privat/tnftp-${TNFTP_VERSION}.tar.gz"
)

run_build_setup "tnftp" "${TNFTP_VERSION}" "${TNFTP_TARBALL}" \
  -- "${TNFTP_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache pkgconfig ncurses-dev ncurses-static openssl-dev openssl-libs-static libedit-dev libedit-static
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${TNFTP_TARBALL}
cd tnftp-${TNFTP_VERSION}/
echo -e "${PEACH}= Configure source${NC}"
./configure --disable-ipv6 --enable-ssl --with-socks=no --enable-editcomplete \
  --disable-shared --enable-static \
  LDFLAGS='${BLDFLAGS} ${MOLD} -no-pie -w -Wl,-s' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fno-pie'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip src/tnftp
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
upx --lzma src/tnftp
EOF

package_output "tnftp" "./${CHROOTDIR}/tnftp-${TNFTP_VERSION}/src/tnftp"

