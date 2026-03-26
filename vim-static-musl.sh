#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

setup_tools

echo -e "${VIOLET}= fetching latest vim version${NC}"
VIM_VERSION=$(gh_latest_tag "vim/vim" '.[0].name | ltrimstr("v")') || true
if [ -z "${VIM_VERSION}" ]; then
  echo -e "${TAWNY}= GitHub API unavailable, falling back to vim 9.2.0119${NC}"
  VIM_VERSION="9.2.0119"
fi

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
apk update && apk add build-base ccache sed patch pkgconfig ncurses-dev ncurses-static ncurses-terminfo
apk upgrade musl-dev --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
chmod 755 upx
echo -e "${LIME}= Extracting source${NC}"
tar xf ${VIM_TARBALL}
cd vim-${VIM_VERSION}/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=4 < ../vim.patch
sed -i 's#emsg(_(e_failed_to_source_defaults));#(void)0;#g' src/main.c
echo -e "${PEACH}= Configure source${NC}"
./configure --disable-arabic --disable-canberra --disable-darwin --disable-farsi --disable-gpm --disable-gtktest \
  --disable-gui --disable-libsodium --disable-netbeans --disable-nls --disable-rightleft --disable-selinux \
  --disable-smack --disable-sysmouse --disable-xsmp --enable-largefile --enable-multibyte --enable-terminal \
  --enable-year2038 --with-features=huge --with-tlib=ncursesw  --without-gnome --without-x --without-wayland
  LDFLAGS='${BASE_LDFLAGS} -w -Wl,-s -no-pie' PKG_CONFIG='${BASE_PKGCFG}' \
  CFLAGS='${BASE_CFLAGS} ${ARCH_FLAGS} ${EXTRA_CFLAGS} ${LTOFLAGS} -fno-pie'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip src/vim
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
../upx --lzma src/vim
EOF

package_output "vim" "./${CHROOTDIR}/vim-${VIM_VERSION}/src/vim"
