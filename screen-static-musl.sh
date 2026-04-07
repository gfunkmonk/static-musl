#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${MINT}= fetching latest screen version${NC}"
SCREEN_VERSION=$(get_git_version "https://cgit.git.savannah.gnu.org/cgit/screen.git/refs/tags" "[0-9]+\.[0-9]+(\.[0-9]+)*" "v" "${FALLBACK_SCREEN}")
#SCREEN_VERSION=$("${CURL}" -s https://ftp.gnu.org/gnu/screen/ | grep -oP 'screen-\K[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -n 1)
#[[ -z "${SCREEN_VERSION}" ]] && { echo -e "${TAWNY}= ftp.gnu.org fetch failed, using fallback ${FALLBACK_SCREEN}${NC}" >&2; SCREEN_VERSION="${FALLBACK_SCREEN}"; }
echo -e "${JUNEBUD}= building screen version: ${SCREEN_VERSION}${NC}"
PACKAGE_VERSION="${SCREEN_VERSION}"
SCREEN_TARBALL="screen-${SCREEN_VERSION}.tar.gz"
SCREEN_MIRRORS=(
  "https://ftp.gnu.org/gnu/screen/screen-${SCREEN_VERSION}.tar.gz"
  "https://fossies.org/linux/misc/screen-${SCREEN_VERSION}.tar.gz"
)

run_build_setup "screen" "${SCREEN_VERSION}" "${SCREEN_TARBALL}" \
  "screen-5.0.0-supress_remap.patch" \
  "screen-5.0.1-big-endian.patch" \
  -- "${SCREEN_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache ncurses-dev ncurses-static openssl-dev openssl-libs-static
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${SCREEN_TARBALL}
cd screen-${SCREEN_VERSION}/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../screen-5.0.0-supress_remap.patch
patch -p1 --fuzz=4 < ../screen-5.0.1-big-endian.patch
echo -e "${PEACH}= Configure source${NC}"
./configure CC="${CC}" --enable-telnet --with-pty-mode=0600 --with-pty-group=5 \
  --enable-socket-dir=/run/screen --disable-pam --enable-utmp \
  LDFLAGS='${BLDFLAGS} ${MOLD} ${LNOPIE}' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CNOPIE}'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "screen" "./${CHROOTDIR}/screen-${SCREEN_VERSION}/screen"
