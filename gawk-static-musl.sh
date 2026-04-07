#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${MINT}= fetching latest gawk version${NC}"
#GAWK_VERSION=$(get_git_version "https://cgit.git.savannah.gnu.org/cgit/gawk.git/refs/tags" "[0-9]+\.[0-9]+(\.[0-9]+)*" "gawk-" "${FALLBACK_GAWK}")
GAWK_VERSION=$("${CURL}" -s https://ftp.gnu.org/gnu/gawk/ | grep -oP 'gawk-\K[0-9]+\.[0-9]+(\.[0-9]+)?' | sort -V | tail -n 1)
[[ -z "${GAWK_VERSION}" ]] && { echo -e "${TAWNY}= ftp.gnu.org fetch failed, using fallback ${FALLBACK_GAWK}${NC}" >&2; GAWK_VERSION="${FALLBACK_GAWK}"; }
echo -e "${JUNEBUD}= building gawk version: ${GAWK_VERSION}${NC}"
PACKAGE_VERSION="${GAWK_VERSION}"
GAWK_TARBALL="gawk-${GAWK_VERSION}.tar.xz"
GAWK_MIRRORS=(
  "https://ftp.gnu.org/gnu/gawk/gawk-${GAWK_VERSION}.tar.xz"
  "https://fossies.org/linux/misc/gawk-${GAWK_VERSION}.tar.xz"
)

run_build_setup "gawk" "${GAWK_VERSION}" "${GAWK_TARBALL}" \
  gawk-5.4.0-no-assertions-for-pma.patch \
  gawk-5.4.0-Small-efficiency-fix-in-array.c.patch \
  -- "${GAWK_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache pkgconfig bison readline-dev readline-static
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${GAWK_TARBALL}
cd gawk-${GAWK_VERSION}/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../gawk-5.4.0-no-assertions-for-pma.patch
patch -p1 --fuzz=4 < ../gawk-5.4.0-Small-efficiency-fix-in-array.c.patch
echo -e "${PEACH}= Configure source${NC}"
./configure --disable-nls --disable-rpath \
  LDFLAGS='${BLDFLAGS} ${MOLD} ${NOPIE}' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${NOPIE}'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "gawk" "./${CHROOTDIR}/gawk-${GAWK_VERSION}/gawk"

