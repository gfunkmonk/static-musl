#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${HOTPINK}= fetching latest fping version${NC}"
FPING_VERSION=$(get_version release "schweikert/fping" '.tag_name | ltrimstr("v")' "${FALLBACK_FPING}")
echo -e "${PEACH}= building fping version: ${FPING_VERSION}${NC}"
PACKAGE_VERSION="${FPING_VERSION}"
FPING_TARBALL="fping-${FPING_VERSION}.tar.gz"
FPING_MIRRORS=(
  "https://github.com/schweikert/fping/releases/download/v${FPING_VERSION}/fping-${FPING_VERSION}.tar.gz"
  "https://fossies.org/linux/misc/fping-${FPING_VERSION}.tar.gz"
)

run_build_setup "fping" "${FPING_VERSION}" "${FPING_TARBALL}" \
  -- "${FPING_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${FPING_TARBALL}
cd fping-${FPING_VERSION}/
echo -e "${LAGOON}= Configure source${NC}"
./configure CC="${CC}" --disable-ipv6 \
  LDFLAGS='${BLDFLAGS} ${MOLD} ${LNOPIE}' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CNOPIE}'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "fping" "./${CHROOTDIR}/fping-${FPING_VERSION}/src/fping"