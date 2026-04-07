#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${VIOLET}= fetching latest zsh version${NC}"
ZSH_VERSION=$("${CURL}" -s https://www.zsh.org/pub/ | grep -o 'href="[^"]*.xz"' | grep -e zsh-[0-9] | cut -d'"' -f2 | sort | tail -1 | sed 's/\.tar.*//' | sed 's/zsh-//g')
[[ -z "${ZSH_VERSION}" ]] && { echo -e "${TAWNY}= zsh.org fetch failed, using fallback ${FALLBACK_ZSH}${NC}" >&2; ZSH_VERSION="${FALLBACK_ZSH}"; }
echo -e "${TEAL}= building zsh version: ${ZSH_VERSION}${NC}"
PACKAGE_VERSION="${ZSH_VERSION}"
ZSH_TARBALL="zsh-${ZSH_VERSION}.tar.xz"
ZSH_MIRRORS=(
  "https://www.zsh.org/pub/zsh-${ZSH_VERSION}.tar.xz"
  "https://ftp.funet.fi/pub/unix/shells/zsh/zsh-${ZSH_VERSION}.tar.xz"
  "http://ftp.oregonstate.edu/pub/slackware/slackware/patches/source/zsh/zsh-${ZSH_VERSION}.tar.xz"
)

run_build_setup "zsh" "${ZSH_VERSION}" "${ZSH_TARBALL}" \
  "cherry-pick-0bb140f9-52999-import-OLDPWD-from-environment-if-set.patch" \
  "cherry-pick-3e3cfabc-revert-38150-and-fix-in-calling-function-cfp_matcher_range-instead.patch" \
  "cherry-pick-4b7a9fd0-additional-typset--p--m-fix-for-namespaces.patch" \
  "cherry-pick-10bdbd8b-51877-do-not-build-pcre-module-if-pcre2-config-is-not-found.patch" \
  "cherry-pick-b62e91134-51723-migrate-pcre-module-to-pcre2.patch" \
  "cross-compile.diff" \
  -- "${ZSH_MIRRORS[@]}"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache sed autoconf automake pkgconfig ncurses-dev ncurses-static ncurses-terminfo groff pcre2-dev pcre2-static git clang gdbm-dev
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${ZSH_TARBALL}
cd zsh-${ZSH_VERSION}/
echo -e "${LAGOON}= Applying custom patch${NC}"
patch -p1 --fuzz=6 < ../cherry-pick-b62e91134-51723-migrate-pcre-module-to-pcre2.patch
patch -p1 --fuzz=6 < ../cherry-pick-0bb140f9-52999-import-OLDPWD-from-environment-if-set.patch
patch -p1 --fuzz=6 < ../cherry-pick-3e3cfabc-revert-38150-and-fix-in-calling-function-cfp_matcher_range-instead.patch
patch -p1 --fuzz=6 < ../cherry-pick-4b7a9fd0-additional-typset--p--m-fix-for-namespaces.patch
patch -p1 --fuzz=6 < ../cherry-pick-10bdbd8b-51877-do-not-build-pcre-module-if-pcre2-config-is-not-found.patch
patch -p1 --fuzz=6 < ../cross-compile.diff
echo -e "${PEACH}= Configure source${NC}"
./configure CC='clang' --enable-max-jobtable-size=256 --enable-etcdir=/etc/zsh --enable-function-subdirs --with-tcsetpgrp --enable-cap \
  --enable-pcre --disable-ansi2knr --disable-dynamic --disable-dynamic-nss --enable-libc-musl --enable-maildir-support  --enable-gdbm \
  --with-term-lib="ncursesw tinfo" --enable-ldflags='${BLDFLAGS} ${MOLD} ${NOPIE}' \
  --enable-cflags='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${NOPIE} -Wno-unused-variable -Wno-implicit-function-declaration' \
  LDFLAGS='${BLDFLAGS} ${MOLD} ${NOPIE}' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${NOPIE} -Wno-unused-variable -Wno-implicit-function-declaration'
echo -e "${VIOLET}= Building...${NC}"
CC='clang' make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "zsh" "./${CHROOTDIR}/zsh-${ZSH_VERSION}/Src/zsh"
