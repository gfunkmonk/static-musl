#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${MINT}= fetching latest mc version${NC}"
MC_VERSION=$("${CURL}" -s https://ftp.osuosl.org/pub/midnightcommander/ | grep -oP 'mc-\K[0-9]+\.[0-9]+(\.[0-9]+)?' | sort -V | tail -n 1)
[[ -z "${MC_VERSION}" ]] && { echo -e "${TAWNY}= mc source fetch failed, using fallback ${FALLBACK_MC}${NC}" >&2; MC_VERSION="${FALLBACK_MC}"; }
echo -e "${JUNEBUD}= building mc version: ${MC_VERSION}${NC}"
PACKAGE_VERSION="${MC_VERSION}"
MC_TARBALL="mc-${MC_VERSION}.tar.xz"
MC_MIRRORS=(
  "https://ftp.osuosl.org/pub/midnightcommander/mc-${MC_VERSION}.tar.xz"
  "https://fossies.org/linux/misc/mc-${MC_VERSION}.tar.xz"
  "https://mirrors.mit.edu/macports/distfiles/mc/mc-${MC_VERSION}.tar.xz"
)
run_build_setup "mc" "${MC_VERSION}" "${MC_TARBALL}" \
  "2987.patch" \
  "disable_internal_editor.patch" \
  -- "${MC_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache pkgconfig ncurses-dev ncurses-static glib-dev glib-static pcre2-dev \
  pcre2-static libffi-dev zlib-dev zlib-static linux-headers slang-dev slang-static libedit-dev libedit-static
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${MC_TARBALL}
cd mc-${MC_VERSION}/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../2987.patch
patch -p1 --fuzz=4 < ../disable_internal_editor.patch
echo -e "${PEACH}= Configure source${NC}"
./configure CC="${CC}" \
  --disable-nls --disable-tests --disable-doxygen-doc --without-gnutls --without-mclib \
  --without-x --enable-charset --disable-vfs-sftp --disable-vfs-undelfs --enable-static \
  --disable-shared --prefix=/usr --sysconfdir=/etc --libexecdir=/usr/lib \
  LDFLAGS='${BLDFLAGS} ${MOLD} ${LNOPIE}' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CNOPIE}'
echo -e "${VIOLET}= Building...${NC}"
CC="${CC}" make -j\$(nproc) LDFLAGS='-all-static ${BLDFLAGS} ${MOLD} ${LNOPIE}'
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "mc" "./${CHROOTDIR}/mc-${MC_VERSION}/src/mc"