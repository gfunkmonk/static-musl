#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

setup_tools

echo -e "${VIOLET}= fetching latest htop version${NC}"
HTOP_VERSION=$(gh_latest_release "htop-dev/htop") || true
if [ -z "${HTOP_VERSION}" ]; then
  echo -e "${TAWNY}= GitHub API unavailable, falling back to htop 3.4.1${NC}"
  HTOP_VERSION="3.4.1"
fi

PACKAGE_VERSION="${HTOP_VERSION}"
HTOP_TARBALL="htop-${HTOP_VERSION}.tar.xz"
HTOP_MIRRORS=(
  "https://github.com/htop-dev/htop/releases/download/${HTOP_VERSION}/htop-${HTOP_VERSION}.tar.xz"
  "https://fossies.org/linux/misc/htop-${HTOP_VERSION}.tar.xz"
)

run_build_setup "htop" "${HTOP_VERSION}" "${HTOP_TARBALL}" \
  "htop.patch" \
  -- "${HTOP_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base ccache pkgconfig ncurses-dev \
  ncurses-static python3 lm-sensors-dev libnl3-dev libnl3-static linux-headers
apk upgrade musl-dev --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
chmod 755 upx
echo -e "${LIME}= Extracting source${NC}"
tar xf ${HTOP_TARBALL}
cd htop-${HTOP_VERSION}/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../htop.patch
echo -e "${PEACH}= Configure source${NC}"
./configure CC='gcc' \
  --enable-unicode --enable-static --enable-affinity --enable-delayacct \
  LDFLAGS='${BASE_LDFLAGS}' PKG_CONFIG='${BASE_PKGCFG}' \
  CFLAGS='${BASE_CFLAGS} ${ARCH_FLAGS} -no-pie'
echo -e "${VIOLET}= Building...${NC}"
CC='gcc' make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip htop
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
../upx --lzma htop
EOF

package_output "htop" "./${CHROOTDIR}/htop-${HTOP_VERSION}/htop"
