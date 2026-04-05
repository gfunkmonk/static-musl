#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${TEAL}= fetching latest netcat-openbsd version${NC}"
NETCAT_VERSION=$("${CURL}" -s "https://salsa.debian.org/api/v4/projects/debian%2Fnetcat-openbsd/repository/tags" | \
  "${JQ}" -r '[.[] | select(.name | test("^[0-9]"))] | .[0].name // empty' 2>/dev/null)
[[ -z "${NETCAT_VERSION}" ]] && { echo -e "${TAWNY}= salsa API unavailable, using fallback ${FALLBACK_NETCAT}${NC}" >&2; NETCAT_VERSION="${FALLBACK_NETCAT}"; }
echo -e "${AQUA}= building netcat-openbsd version: ${NETCAT_VERSION}${NC}"
PACKAGE_VERSION="${NETCAT_VERSION}"
NETCAT_TARBALL="netcat-openbsd-${NETCAT_VERSION}.tar.gz"
NETCAT_MIRRORS=(
  "https://salsa.debian.org/debian/netcat-openbsd/-/archive/${NETCAT_VERSION}/netcat-openbsd-${NETCAT_VERSION}.tar.gz"
)

run_build_setup "netcat" "${NETCAT_VERSION}" "${NETCAT_TARBALL}" \
  -- "${NETCAT_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache libbsd-dev libbsd-static libmd-dev libmd-static
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${NETCAT_TARBALL}
cd netcat-openbsd-${NETCAT_VERSION}/
echo -e "${PEACH}= Building...${NC}"
make CC="${CC}" \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fno-PIE' \
  LDFLAGS='${BLDFLAGS} ${MOLD} -no-pie -lbsd' \
  -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "netcat" "./${CHROOTDIR}/netcat-openbsd-${NETCAT_VERSION}/nc"
