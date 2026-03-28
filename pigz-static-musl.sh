#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

echo -e "${VIOLET}= fetching latest pigz version${NC}"
PIGZ_VERSION=$(get_version tag "madler/pigz" ".[0].name | ltrimstr("v")" "2.8")

PACKAGE_VERSION="${PIGZ_VERSION}"
PIGZ_TARBALL="pigz-${PIGZ_VERSION}.tar.gz"
PIGZ_MIRRORS=(
  "https://github.com/madler/pigz/archive/v${PIGZ_VERSION}/pigz-${PIGZ_VERSION}.tar.gz"
  "https://zlib.net/pigz/pigz-${PIGZ_VERSION}.tar.gz"
  "https://fossies.org/linux/privat/pigz-${PIGZ_VERSION}.tar.gz"
)

run_build_setup "pigz" "${PIGZ_VERSION}" "${PIGZ_TARBALL}" \
  -- "${PIGZ_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache sed zlib-dev zlib-static
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${PIGZ_TARBALL}
cd pigz-${PIGZ_VERSION}/
sed -i 's/CFLAGS=-O3 -Wall -Wextra -Wno-unknown-pragmas -Wcast-qual/CFLAGS=${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fno-PIE/g' Makefile
sed -i 's/LDFLAGS=/LDFLAGS=${BLDFLAGS} ${MOLD} -no-pie -w -Wl,-s/g' Makefile
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip pigz
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
upx --lzma pigz
EOF

package_output "pigz" "./${CHROOTDIR}/pigz-${PIGZ_VERSION}/pigz"