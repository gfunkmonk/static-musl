#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

setup_tools

PIGZ_VERSION="2.8"
PACKAGE_VERSION="${PIGZ_VERSION}"
PIGZ_TARBALL="pigz-${PIGZ_VERSION}.tar.gz"
PIGZ_MIRRORS=(
  "https://zlib.net/pigz/pigz-${PIGZ_VERSION}.tar.gz"
  "https://fossies.org/linux/privat/pigz-${PIGZ_VERSION}.tar.gz"
  "https://gentoo.osuosl.org/distfiles/70/pigz-${PIGZ_VERSION}.tar.gz"
)

run_build_setup "pigz" "${PIGZ_VERSION}" "${PIGZ_TARBALL}" \
  -- "${PIGZ_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
apk update && apk add build-base musl-dev ccache sed zlib-dev zlib-static
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
chmod 755 upx
tar xf pigz-${PIGZ_VERSION}.tar.gz
cd pigz-${PIGZ_VERSION}/
sed -i 's/CFLAGS=-O3 -Wall -Wextra -Wno-unknown-pragmas -Wcast-qual/CFLAGS=-Os -static ${ARCH_FLAGS} -ffunction-sections -fdata-sections -fomit-frame-pointer -fno-stack-protector -no-pie/g' Makefile
sed -i 's/LDFLAGS=/LDFLAGS=-static -Wl,--gc-sections/g' Makefile
make -j\$(nproc)
strip pigz
../upx --lzma pigz
EOF

package_output "pigz" "./${CHROOTDIR}/pigz-${PIGZ_VERSION}/pigz"