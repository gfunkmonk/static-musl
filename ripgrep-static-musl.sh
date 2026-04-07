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
  echo -e "${SLATE}= Cross-compiling ripgrep on host (QEMU-arm too slow / no Alpine Rust pkg for ${ARCH})${NC}"

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

  echo -e "${LIME}= Extracting ripgrep source${NC}"
  BUILD_DIR=$(mktemp -d)
  tar xf "distfiles/${RIPGREP_TARBALL}" -C "${BUILD_DIR}"

  echo -e "${VIOLET}= Building ripgrep ${RIPGREP_VERSION} for ${ARCH} (cross-compilation on host)${NC}"
  pushd "${BUILD_DIR}/ripgrep-${RIPGREP_VERSION}/"
  RUSTFLAGS="-C target-feature=+crt-static" \
    cargo zigbuild --release --target "${RUST_TARGET}"
  popd

  package_output "ripgrep" "${BUILD_DIR}/ripgrep-${RIPGREP_VERSION}/target/${RUST_TARGET}/release/rg"
  rm -rf "${BUILD_DIR}"
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
export RUSTFLAGS="-C target-feature=+crt-static"
cargo build --release
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

  package_output "ripgrep" "./${CHROOTDIR}/ripgrep-${RIPGREP_VERSION}/target/release/rg"
fi