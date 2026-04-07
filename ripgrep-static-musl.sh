#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${CANARY}= fetching latest ripgrep version${NC}"
RIPGREP_VERSION=$(get_version release "BurntSushi/ripgrep" '.tag_name | ltrimstr("v")' "${FALLBACK_RIPGREP}")
echo -e "${SLATE}= building ripgrep version: ${RIPGREP_VERSION}${NC}"
PACKAGE_VERSION="${RIPGREP_VERSION}"
RIPGREP_TARBALL="ripgrep-${RIPGREP_VERSION}.tar.gz"
RIPGREP_MIRRORS=(
  "https://github.com/BurntSushi/ripgrep/archive/${RIPGREP_VERSION}/ripgrep-${RIPGREP_VERSION}.tar.gz"
  "https://fossies.org/linux/misc/ripgrep-${RIPGREP_VERSION}.tar.gz"
  "https://sources.voidlinux.org/ripgrep-${RIPGREP_VERSION}/ripgrep-${RIPGREP_VERSION}.tar.gz"
)

run_build_setup "ripgrep" "${RIPGREP_VERSION}" "${RIPGREP_TARBALL}" \
  -- "${RIPGREP_MIRRORS[@]}"

rust_set_cross_target

if [ -n "${RUST_TARGET}" ]; then
  rust_host_cross_build "ripgrep" "${RIPGREP_VERSION}" "${RIPGREP_TARBALL}" "ripgrep-${RIPGREP_VERSION}" "rg"
else
  sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base ccache rust cargo
apk upgrade musl-dev --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${RIPGREP_TARBALL}
cd ripgrep-${RIPGREP_VERSION}/
echo -e "${VIOLET}= Building...${NC}"
export CARGO_PROFILE_RELEASE_OPT_LEVEL="z"
export CARGO_PROFILE_RELEASE_LTO="true"
export CARGO_PROFILE_RELEASE_STRIP="symbols"
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS="1"
export RUSTFLAGS="-C target-feature=+crt-static link-arg=-fuse-ld=mold"
cargo build --release
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

  package_output "ripgrep" "./${CHROOTDIR}/ripgrep-${RIPGREP_VERSION}/target/release/rg"
fi