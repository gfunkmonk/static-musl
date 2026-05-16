#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${VIOLET}= fetching latest zsh version${NC}"
ZSH_VERSION=$(get_web_version "https://www.zsh.org/pub/" 'href="[^"]*.xz"' | grep -e zsh-[0-9] | cut -d'"' -f2 | sort | tail -1 | sed 's/\.tar.*//' | sed 's/zsh-//g')
[[ -z "${ZSH_VERSION}" ]] && { echo -e "${TAWNY}= zsh.org fetch failed, using fallback ${FALLBACK_ZSH}${NC}" >&2; ZSH_VERSION="${FALLBACK_ZSH}"; }
echo -e "${TEAL}= building zsh version: ${ZSH_VERSION}${NC}"
PACKAGE_VERSION="${ZSH_VERSION}"
ZSH_TARBALL="zsh-${ZSH_VERSION}.tar.xz"
ZSH_MIRRORS=(
  "https://www.zsh.org/pub/zsh-${ZSH_VERSION}.tar.xz"
  "https://ftp.funet.fi/pub/unix/shells/zsh/zsh-${ZSH_VERSION}.tar.xz"
  "http://ftp.oregonstate.edu/pub/slackware/slackware/patches/source/zsh/zsh-${ZSH_VERSION}.tar.xz"
  "https://mirrors.slackware.com/slackware/slackware-current/source/ap/zsh/zsh-${ZSH_VERSION}.tar.xz"
)

run_build_setup "zsh" "${ZSH_VERSION}" "${ZSH_TARBALL}" \
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
echo -e "${PEACH}= Configure source${NC}"
./configure CC='clang' --enable-max-jobtable-size=256 --enable-etcdir=/etc/zsh --enable-function-subdirs --with-tcsetpgrp --enable-cap \
  --enable-pcre --disable-ansi2knr --disable-dynamic --disable-dynamic-nss --enable-libc-musl --enable-maildir-support  --enable-gdbm \
  --with-term-lib="ncursesw tinfo" --enable-ldflags='${BLDFLAGS} ${MOLD} ${LNOPIE}' \
  --enable-cflags='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CNOPIE} -Wno-unused-variable -Wno-implicit-function-declaration' \
  LDFLAGS='${BLDFLAGS} ${MOLD} ${LNOPIE}' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CNOPIE} -Wno-unused-variable -Wno-implicit-function-declaration'
echo -e "${VIOLET}= Building...${NC}"
CC='clang' make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "zsh" "./${CHROOTDIR}/zsh-${ZSH_VERSION}/Src/zsh"
