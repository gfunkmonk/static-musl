#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${JUNEBUD}= fetching latest dropbear version${NC}"
DROPBEAR_VERSION=$(get_version release "mkj/dropbear" '.tag_name | ltrimstr("DROPBEAR_")' "${FALLBACK_DROPBEAR}")
echo -e "${SLATE}= building dropbear version: ${DROPBEAR_VERSION}${NC}"
PACKAGE_VERSION="${DROPBEAR_VERSION}"
DROPBEAR_TARBALL="dropbear-${DROPBEAR_VERSION}.tar.bz2"
DROPBEAR_MIRRORS=(
  "https://matt.ucc.asn.au/dropbear/releases/dropbear-${DROPBEAR_VERSION}.tar.bz2"
  "https://dropbear.nl/mirror/releases/dropbear-${DROPBEAR_VERSION}.tar.bz2"
)

run_build_setup "dropbear" "${DROPBEAR_VERSION}" "${DROPBEAR_TARBALL}" \
  "dropbear-options_keepalive.patch" \
  "dropbear-options_sftp-server_path.patch" \
  "dropbear-options_ssh_config.patch" \
  "dropbear-scp.patch" \
  -- "${DROPBEAR_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${HELIOTROPE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache openssl-dev openssl-libs-static zlib-dev zlib-static
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LEMON}= Extracting source${NC}"
tar xf ${DROPBEAR_TARBALL}
cd dropbear-${DROPBEAR_VERSION}/
echo -e "${LAGOON}= Applying custom patch(es)${NC}"
patch -p1 --fuzz=4 < ../dropbear-options_ssh_config.patch
patch -p1 --fuzz=4 < ../dropbear-options_sftp-server_path.patch
patch -p1 --fuzz=4 < ../dropbear-options_keepalive.patch
patch -p1 --fuzz=4 < ../dropbear-scp.patch
echo -e "${CHARTREUSE}= Configure source${NC}"
./configure CC="${CC}" \
  --disable-lastlog --disable-utmp --disable-utmpx --disable-wtmp --disable-wtmpx \
  --disable-pututline --disable-pututxline --enable-bundled-libtom --disable-pam \
  --enable-zlib --enable-static \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${NOPIE} -Wno-incompatible-pointer-types -Wno-undef' \
  LDFLAGS='${BLDFLAGS} ${MOLD} ${NOPIE}' PKG_CONFIG='${PKGCFG}'
echo -e "${PURPLE_BLUE}= Building...${NC}"
CC="${CC}" make -j\$(nproc) MULTI=1 STATIC=1
cp dropbearmulti dropbear
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "dropbear" "./${CHROOTDIR}/dropbear-${DROPBEAR_VERSION}/dropbear"
