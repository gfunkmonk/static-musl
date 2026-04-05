#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${CANARY}= fetching latest ripgrep version${NC}"
RG_VERSION=$(get_version release "BurntSushi/ripgrep" '.tag_name | ltrimstr("v")' "${FALLBACK_RIPGREP}")
echo -e "${SLATE}= building ripgrep version: ${RG_VERSION}${NC}"
PACKAGE_VERSION="${RG_VERSION}"
RG_TARBALL="ripgrep-${RG_VERSION}.tar.gz"
RG_MIRRORS=(
  "https://github.com/BurntSushi/ripgrep/archive/${RG_VERSION}/ripgrep-${RG_VERSION}.tar.gz"
  "https://github.com/BurntSushi/ripgrep/archive/refs/tags/${RG_VERSION}.tar.gz"
)

run_build_setup "ripgrep" "${RG_VERSION}" "${RG_TARBALL}" \
  -- "${RG_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base ccache rust cargo
apk upgrade musl-dev --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${RG_TARBALL}
cd ripgrep-${RG_VERSION}/
echo -e "${VIOLET}= Building...${NC}"
export RUSTFLAGS="-C target-feature=+crt-static"
cargo build --release
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "ripgrep" "./${CHROOTDIR}/ripgrep-${RG_VERSION}/target/release/rg"
