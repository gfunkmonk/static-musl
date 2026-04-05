#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${MINT}= fetching latest vim version (for xxd)${NC}"
VIM_VERSION=$(get_version tag "vim/vim" '.[0].name | ltrimstr("v")' "${FALLBACK_VIM}")
echo -e "${OCHRE}= building xxd version: ${VIM_VERSION}${NC}"
PACKAGE_VERSION="${VIM_VERSION}"
VIM_TARBALL="vim-${VIM_VERSION}.tar.gz"
VIM_MIRRORS=(
  "https://github.com/vim/vim/archive/v${VIM_VERSION}/vim-${VIM_VERSION}.tar.gz"
  "https://fossies.org/linux/misc/vim-${VIM_VERSION}.tar.gz"
)

run_build_setup "xxd" "${VIM_VERSION}" "${VIM_TARBALL}" \
  -- "${VIM_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${VIM_TARBALL}
cd vim-${VIM_VERSION}/src/xxd/
echo -e "${PEACH}= Building xxd${NC}"
make CC="${CC}" \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fno-PIE' \
  LDFLAGS='${BLDFLAGS} ${MOLD} -no-pie' \
  -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "xxd" "./${CHROOTDIR}/vim-${VIM_VERSION}/src/xxd/xxd"
