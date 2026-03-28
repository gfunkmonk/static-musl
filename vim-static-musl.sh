#!/bin/bash
set -euo pipefail
. $(dirname "${BASH_SOURCE[0]}")/common.sh

echo -e "${MINT}= fetching latest vim version${NC}"
VIM_VERSION=$(get_version tag "vim/vim" '.[0].name | ltrimstr("v")' "9.2.0119")
echo -e "${JUNEBUD}= building vim version: ${VIM_VERSION}${NC}"
PACKAGE_VERSION="${VIM_VERSION}"
VIM_TARBALL="vim-${VIM_VERSION}.tar.gz"
VIM_MIRRORS=(
  "https://github.com/vim/vim/archive/v${VIM_VERSION}/vim-${VIM_VERSION}.tar.gz"
  "https://fossies.org/linux/misc/vim-${VIM_VERSION}.tar.gz"
)

run_build_setup "vim" "${VIM_VERSION}" "${VIM_TARBALL}" \
  "vim.patch" \
  -- "${VIM_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache sed patch pkgconfig ncurses-dev ncurses-static ncurses-terminfo
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${VIM_TARBALL}
cd vim-${VIM_VERSION}/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../vim.patch
sed -i 's#emsg(_(e_failed_to_source_defaults));#(void)0;#g' src/main.c
echo -e "${PEACH}= Configure source${NC}"
./configure CC=gcc --disable-arabic --disable-canberra --disable-darwin --disable-farsi --disable-gpm --disable-gtktest \
  --disable-gui --disable-libsodium --disable-netbeans --disable-nls --disable-rightleft --disable-selinux \
  --disable-smack --disable-sysmouse --disable-xsmp --enable-largefile --enable-multibyte --enable-terminal \
  --enable-year2038 --with-features=huge --with-tlib=ncursesw  --without-gnome --without-x --without-wayland \
  LDFLAGS='${BLDFLAGS} ${MOLD} -no-pie -w -Wl,-s' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} -fno-PIE'
echo -e "${VIOLET}= Building...${NC}"
CC=gcc make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip src/vim
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
upx --lzma src/vim
EOF

package_output "vim" "./${CHROOTDIR}/vim-${VIM_VERSION}/src/vim"
