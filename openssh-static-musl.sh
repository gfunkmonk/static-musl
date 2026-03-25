#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

setup_tools

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
apk update && apk add build-base musl-dev ccache openssl-dev openssl-libs-static zlib-dev zlib-static autoconf automake
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
chmod 755 upx
echo -e "${LIME}= Extracting source${NC}"
tar xf openssh-${OPENSSH_VERSION}.tar.gz
cd openssh-${OPENSSH_VERSION}/
echo -e "${PEACH}= Configure source${NC}"
./configure --with-privsep-user=nobody \
  LIBS='-pthread' LDFLAGS='-static -Wl,--gc-sections' PKG_CONFIG='pkg-config --static' \
  CFLAGS='-Os -static ${ARCH_FLAGS} -ffunction-sections -fdata-sections -fomit-frame-pointer -fno-stack-protector -no-pie -Wno-unterminated-string-initialization'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip ssh
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
../upx --lzma ssh
EOF

package_output "openssh" "./${CHROOTDIR}/openssh-${OPENSSH_VERSION}/ssh"
