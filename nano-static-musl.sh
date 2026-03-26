#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

NANO_VERSION="8.7.1"
PACKAGE_VERSION="${NANO_VERSION}"
NANO_TARBALL="nano-${NANO_VERSION}.tar.xz"
NANO_MIRRORS=(
  "https://www.nano-editor.org/dist/v8/nano-${NANO_VERSION}.tar.xz"
  "https://fossies.org/linux/misc/nano-${NANO_VERSION}.tar.xz"
  "https://mirrors.slackware.com/slackware/slackware-current/source/ap/nano/nano-${NANO_VERSION}.tar.xz"
  "https://artfiles.org/gnupg.org/nano/nano-${NANO_VERSION}.tar.xz"
  "https://pilotfiber.dl.sourceforge.net/project/immortalwrt/sources/nano-${NANO_VERSION}.tar.xz"
)

run_build_setup "nano" "${NANO_VERSION}" "${NANO_TARBALL}" \
  "nano-colors.patch" \
  -- "${NANO_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base ccache pkgconfig ncurses-dev ncurses-static libmagic-static libmagic file-dev linux-headers
apk upgrade musl-dev --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
chmod 755 upx
echo -e "${LIME}= Extracting source${NC}"
tar xf ${NANO_TARBALL}
cd nano-${NANO_VERSION}/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../nano-colors.patch
echo -e "${PEACH}= Configure source${NC}"
./configure CC='gcc' \
  --sysconfdir=/etc --disable-nls --disable-utf8 --disable-tiny --enable-nanorc --enable-color \
  --enable-extra --enable-largefile --enable-libmagic --disable-justify \
  LDFLAGS='${BASE_LDFLAGS} -w -Wl,-s -no-pie' PKG_CONFIG='${BASE_PKGCFG}' CFLAGS='${BASE_CFLAGS} ${ARCH_FLAGS} ${EXTRA_CFLAGS} ${LTOFLAGS} -fno-pie'
echo -e "${VIOLET}= Building...${NC}"
CC='gcc' make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip src/nano
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
../upx --lzma src/nano
EOF

package_output "nano" "./${CHROOTDIR}/nano-${NANO_VERSION}/src/nano"
