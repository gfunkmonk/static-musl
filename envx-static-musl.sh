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

# armhf (ARMv6) and armv7 have no pre-built Rust packages in Alpine, so
# compiling cargo inside the QEMU-emulated chroot takes many hours and often
# hangs completely.  Instead, cross-compile on the native host using
# cargo-zigbuild, which bundles a musl-aware Zig toolchain and requires no
# system cross-compiler.
case "${ARCH}" in
  armhf) RUST_TARGET="arm-unknown-linux-musleabihf"  ;;
  armv7) RUST_TARGET="armv7-unknown-linux-musleabihf" ;;
  *)     RUST_TARGET="" ;;
esac

if [ -n "${RUST_TARGET}" ]; then
  echo -e "${SLATE}= Cross-compiling envx on host (QEMU-arm too slow / no Alpine Rust pkg for ${ARCH})${NC}"

  echo -e "${ORANGE}= Installing zig (musl cross-linker) via pip${NC}"
  pip3 install --user --quiet ziglang
  export PATH="${HOME}/.local/bin:${PATH}"

  # rustup is pre-installed on GitHub Actions runners; only bootstrap as a fallback
  if ! command -v rustup >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get install -qy --no-install-recommends rustup
    else
      echo -e "${CRIMSON}= ERROR: rustup not found and apt-get unavailable${NC}" >&2
      exit 1
    fi
  fi
  # shellcheck source=/dev/null
  source "${HOME}/.cargo/env" 2>/dev/null || true

  rustup target add "${RUST_TARGET}"
  if ! command -v cargo-zigbuild >/dev/null 2>&1; then
    cargo install cargo-zigbuild --locked
  fi

  echo -e "${LIME}= Extracting envx source${NC}"
  BUILD_DIR=$(mktemp -d)
  tar xf "distfiles/${ENVX_TARBALL}" -C "${BUILD_DIR}"

  echo -e "${VIOLET}= Building envx ${ENVX_VERSION} for ${ARCH} (cross-compilation on host)${NC}"
  pushd "${BUILD_DIR}/envx-${ENVX_VERSION}/"
  RUSTFLAGS="-C target-feature=+crt-static" \
    cargo zigbuild --release --target "${RUST_TARGET}"
  popd

  package_output "envx" "${BUILD_DIR}/envx-${ENVX_VERSION}/target/${RUST_TARGET}/release/envx"
  rm -rf "${BUILD_DIR}"
else
  sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base ccache rust cargo
apk upgrade musl-dev --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${ENVX_TARBALL}
cd envx-${ENVX_VERSION}/
echo -e "${VIOLET}= Building...${NC}"
export RUSTFLAGS="-C target-feature=+crt-static"
cargo build --target ${NATIVE_RUST_TARGET} --release
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

  package_output "envx" "./${CHROOTDIR}/envx-${ENVX_VERSION}/target/${NATIVE_RUST_TARGET}/release/envx"
fi