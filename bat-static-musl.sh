#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${CANARY}= fetching latest bat version${NC}"
BAT_VERSION=$(get_version release "sharkdp/bat" '.tag_name | ltrimstr("v")' "${FALLBACK_BAT}")
echo -e "${SLATE}= building bat version: ${BAT_VERSION}${NC}"
PACKAGE_VERSION="${BAT_VERSION}"
BAT_TARBALL="bat-${BAT_VERSION}.tar.gz"
BAT_MIRRORS=(
  "https://github.com/sharkdp/bat/archive/v${BAT_VERSION}/bat-${BAT_VERSION}.tar.gz"
  "https://fossies.org/linux/misc/bat-${BAT_VERSION}.tar.gz"
)

run_build_setup "bat" "${BAT_VERSION}" "${BAT_TARBALL}" \
  -- "${BAT_MIRRORS[@]}"

# NATIVE_RUST_TARGET holds the full musl target set by common.sh (e.g. x86_64-alpine-linux-musl).
# The case block below re-uses RUST_TARGET as a flag: non-empty means "cross-compile on host",
# empty means "build inside the Alpine chroot" — but the chroot build still needs the native target.
NATIVE_RUST_TARGET="${RUST_TARGET}"

rust_set_cross_target
if [ -n "${RUST_TARGET}" ]; then
  rust_host_cross_build "bat" "${BAT_VERSION}" "${BAT_TARBALL}" "bat-${BAT_VERSION}" "bat"
else
  sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base ccache rust cargo
apk upgrade musl-dev --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${BAT_TARBALL}
cd bat-${BAT_VERSION}/
echo -e "${VIOLET}= Building...${NC}"
export CARGO_PROFILE_RELEASE_OPT_LEVEL="z"
export CARGO_PROFILE_RELEASE_LTO="true"
export CARGO_PROFILE_RELEASE_STRIP="symbols"
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS="1"
export RUSTFLAGS="-C target-feature=+crt-static"
cargo build --target ${NATIVE_RUST_TARGET} --release
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

  package_output "bat" "./${CHROOTDIR}/bat-${BAT_VERSION}/target/${NATIVE_RUST_TARGET}/release/bat"
fi