#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${CANARY}= fetching latest envx version${NC}"
ENVX_VERSION=$(get_version release "mikeleppane/envx" '.tag_name | ltrimstr("v")' "${FALLBACK_ENVX}")
echo -e "${SLATE}= building envx version: ${ENVX_VERSION}${NC}"
PACKAGE_VERSION="${ENVX_VERSION}"
ENVX_TARBALL="envx-${ENVX_VERSION}.tar.gz"
ENVX_MIRRORS=(
  "https://github.com/mikeleppane/envx/archive/v${ENVX_VERSION}/envx-${ENVX_VERSION}.tar.gz"
)

run_build_setup "envx" "${ENVX_VERSION}" "${ENVX_TARBALL}" \
  -- "${ENVX_MIRRORS[@]}"

# NATIVE_RUST_TARGET holds the full musl target set by common.sh (e.g. x86_64-alpine-linux-musl).
# The case block below re-uses RUST_TARGET as a flag: non-empty means "cross-compile on host",
# empty means "build inside the Alpine chroot" — but the chroot build still needs the native target.
NATIVE_RUST_TARGET="${RUST_TARGET}"

rust_set_cross_target

if [ -n "${RUST_TARGET}" ]; then
  rust_host_cross_build "envx" "${ENVX_VERSION}" "${ENVX_TARBALL}" "envx-${ENVX_VERSION}" "envx"
else
  envx_rustflags="-C target-feature=+crt-static -C link-arg=-fuse-ld=mold"
  if [[ "${ARCH}" == "x86" ]]; then
    envx_rustflags="${envx_rustflags} -C link-arg=-lgcc"
  fi
  sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base ccache mold rust cargo
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${ENVX_TARBALL}
cd envx-${ENVX_VERSION}/
echo -e "${VIOLET}= Building...${NC}"
export CARGO_PROFILE_RELEASE_OPT_LEVEL="z"
export CARGO_PROFILE_RELEASE_LTO="true"
export CARGO_PROFILE_RELEASE_STRIP="symbols"
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS="1"
export RUSTFLAGS="${envx_rustflags}"
cargo build --target ${NATIVE_RUST_TARGET} --release
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

  package_output "envx" "./${CHROOTDIR}/envx-${ENVX_VERSION}/target/${NATIVE_RUST_TARGET}/release/envx"
fi
