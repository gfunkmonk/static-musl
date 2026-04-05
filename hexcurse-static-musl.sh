#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${VIOLET}= fetching latest hexcurse-ng version${NC}"
HEXCURSE_VERSION=$(get_version release "prso/hexcurse-ng" '.tag_name | ltrimstr("v")' "${FALLBACK_HEXCURSE}")
echo -e "${CORAL}= building hexcurse-ng version: ${HEXCURSE_VERSION}${NC}"
PACKAGE_VERSION="${HEXCURSE_VERSION}"
HEXCURSE_TARBALL="hexcurse-ng-${HEXCURSE_VERSION}.tar.gz"
HEXCURSE_MIRRORS=(
  "https://github.com/prso/hexcurse-ng/archive/refs/tags/v${HEXCURSE_VERSION}.tar.gz"
)

run_build_setup "hexcurse" "${HEXCURSE_VERSION}" "${HEXCURSE_TARBALL}" \
  -- "${HEXCURSE_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache pkgconfig ncurses-dev ncurses-static autoconf
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${HEXCURSE_TARBALL}
cd hexcurse-ng-${HEXCURSE_VERSION}/
sed -i 's/-Werror//g' src/Makefile.in
echo -e "${PEACH}= Configure source${NC}"
./configure CC="${CC}" \
  LDFLAGS='${BLDFLAGS} ${MOLD} -no-pie' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fno-PIE'
echo -e "${VIOLET}= Building...${NC}"
CC="${CC}" make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "hexcurse" "./${CHROOTDIR}/hexcurse-ng-${HEXCURSE_VERSION}/src/hexcurse"
