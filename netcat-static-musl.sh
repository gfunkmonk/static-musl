#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${TEAL}= fetching latest netcat-openbsd version${NC}"
NETCAT_VERSION=$("${CURL}" -s "https://salsa.debian.org/api/v4/projects/debian%2Fnetcat-openbsd/repository/tags?per_page=20" | \
  "${JQ}" -r '[.[] | select(.name | test("^debian/"))] | .[0].name | ltrimstr("debian/")' 2>/dev/null)
[[ -z "${NETCAT_VERSION}" || "${NETCAT_VERSION}" == "FAILED" ]] && { echo -e "${TAWNY}= salsa API unavailable, using fallback ${FALLBACK_NETCAT}${NC}" >&2; NETCAT_VERSION="${FALLBACK_NETCAT}"; }
echo -e "${AQUA}= building netcat-openbsd version: ${NETCAT_VERSION}${NC}"
PACKAGE_VERSION="${NETCAT_VERSION}"
NETCAT_TARBALL="netcat-openbsd-debian-${NETCAT_VERSION}.tar.gz"
NETCAT_MIRRORS=(
  "https://salsa.debian.org/debian/netcat-openbsd/-/archive/debian/${NETCAT_VERSION}/netcat-openbsd-debian-${NETCAT_VERSION}.tar.gz"
)

run_build_setup "netcat" "${NETCAT_VERSION}" "${NETCAT_TARBALL}" \
  -- "${NETCAT_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache libbsd-dev libbsd-static libmd-dev
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${NETCAT_TARBALL}
cd netcat-openbsd-debian-${NETCAT_VERSION}/
echo -e "${LAGOON}= Applying Debian patch series${NC}"
while read -r p; do patch -Np1 < debian/patches/"\$p"; done < debian/patches/series
if [ -f ../patches/base64.c ]; then
    echo -e "${MAUVE}= Moving base64.c to source dir${NC}"
    mv ../patches/base64.c .
else
    echo -e "${TOMATO}= Error: file 'base64.c' does not exist!!.${NC}"
fi
if [ -d ../patches ]; then
   # Check if directory is not empty
   if [ "\$(ls -A ../patches 2>/dev/null)" ]; then
       echo -e "${NEONPINK}= Applying custom patch(es)${NC}"
       for p in ../patches/*; do
           if [ -f "\$p" ]; then
               echo -e "${NEONBLUE}Applying \$(basename "\$p")...${NC}"
               patch -p1 --fuzz=2 < "\$p"
           fi
       done
   fi
fi
sed -i 's/^SRCS=.*/& base64.c/' Makefile
echo -e "${PEACH}= Building...${NC}"
make CC="${CC}" \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CNOPIE}' \
  LDFLAGS='${BLDFLAGS} ${MOLD} ${LNOPIE}' \
  LIBS='-lbsd -lmd -lresolv' \
  -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "netcat" "./${CHROOTDIR}/netcat-openbsd-debian-${NETCAT_VERSION}/nc"