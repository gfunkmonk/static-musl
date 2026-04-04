#!/bin/bash
set -euo pipefail
. $(dirname "${BASH_SOURCE[0]}")/common.sh

OPENSSH_VERSION="10.2p1"
PACKAGE_VERSION="${OPENSSH_VERSION}"
OPENSSH_TARBALL="openssh-${OPENSSH_VERSION}.tar.gz"
OPENSSH_MIRRORS=(
  "https://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-${OPENSSH_VERSION}.tar.gz"
  "https://mirrors.slackware.com/slackware/slackware64-current/source/n/openssh/openssh-${OPENSSH_VERSION}.tar.gz"
  "https://mirrors.mit.edu/macports/distfiles/openssh/openssh-${OPENSSH_VERSION}.tar.gz"
)

run_build_setup "openssh" "${OPENSSH_VERSION}" "${OPENSSH_TARBALL}" \
  -- "${OPENSSH_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache openssl-dev openssl-libs-static zlib-dev zlib-static autoconf automake
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${OPENSSH_TARBALL}
cd openssh-${OPENSSH_VERSION}/
echo -e "${PEACH}= Configure source${NC}"
./configure --with-privsep-user=nobody \
  LIBS='-pthread' LDFLAGS='${BLDFLAGS} ${MOLD} -no-pie -w -Wl,-s' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fno-PIE -Wno-unterminated-string-initialization'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip ssh
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
upx --lzma ssh
echo -e "${CARIBBEAN}= ccache statistics:${NC}"
ccache -s
EOF

package_output "openssh" "./${CHROOTDIR}/openssh-${OPENSSH_VERSION}/ssh"
