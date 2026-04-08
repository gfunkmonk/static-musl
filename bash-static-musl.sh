#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

echo -e "${MINT}= fetching latest bash version${NC}"
BASH_VERSION=$(get_git_version "https://cgit.git.savannah.gnu.org/cgit/bash.git/refs/tags" "bash-[0-9]+\.[0-9]+(\.[0-9]+)*" "bash-" "${FALLBACK_BASH}")
echo -e "${JUNEBUD}= building bash version: ${BASH_VERSION}${NC}"
PACKAGE_VERSION="${BASH_VERSION}"
BASH_TARBALL="bash-${BASH_VERSION}.tar.gz"
IFS='.' read -r bash_major bash_minor _ <<< "${BASH_VERSION}"
BASH_MAJOR_MINOR="${bash_major}${bash_minor}"
BASH_PATCH_DIR="bash-${BASH_VERSION}-patches"
BASH_PATCH_PREFIX="bash${BASH_MAJOR_MINOR}-"
BASH_PATCH_URL="https://ftp.gnu.org/gnu/bash/${BASH_PATCH_DIR}/"
BASH_MIRRORS=(
  "https://ftp.gnu.org/gnu/bash/bash-${BASH_VERSION}.tar.gz"
  "https://mirrors.ocf.berkeley.edu/gnu/bash/bash-${BASH_VERSION}.tar.gz"
  "https://mirrors.kernel.org/gnu/bash/bash-${BASH_VERSION}.tar.gz"
  "https://mirrors.ibiblio.org/pub/mirrors/gnu/bash/bash-${BASH_VERSION}.tar.gz"
  "https://mirror.us-midwest-1.nexcess.net/gnu/bash/bash-${BASH_VERSION}.tar.gz"
)

download_bash_upstream_patches() {
  echo -e "${AQUA}= download bash ${BASH_VERSION} upstream patches${NC}"
  mkdir -p distfiles/"${BASH_PATCH_DIR}"
  local patch_index
  if ! patch_index=$("${CURL}" -fsSL "${BASH_PATCH_URL}"); then
    echo -e "${TOMATO}= ERROR: failed to fetch patch index from ${BASH_PATCH_URL}${NC}"
    exit 1
  fi
  BASH_PATCH_FILES=()
  mapfile -t BASH_PATCH_FILES < <(
    # GNU bash patches currently use three-digit numbering (bash53-001, ...). The pattern accepts any digit length in case upstream increases the count.
    printf '%s\n' "${patch_index}" | sed -n "s/.*href=\"\(${BASH_PATCH_PREFIX}[0-9]\+\)\".*/\1/p" | sort -V
  )
  if [ "${#BASH_PATCH_FILES[@]}" -eq 0 ]; then
    echo -e "${TOMATO}= ERROR: no upstream patches found at ${BASH_PATCH_URL}${NC}"
    exit 1
  fi
  local dest
  for patch in "${BASH_PATCH_FILES[@]}"; do
    dest=distfiles/"${BASH_PATCH_DIR}/${patch}"
    if [ -f "${dest}" ]; then
      echo -e "${SLATE}= ${patch} already downloaded${NC}"
      continue
    fi
    if ! "${CURL}" -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 120 \
      -o "${dest}" "${BASH_PATCH_URL}${patch}"; then
      echo -e "${TOMATO}= ERROR: failed to download ${patch} from ${BASH_PATCH_URL}${NC}"
      exit 1
    fi
  done
  for patch in "${BASH_PATCH_FILES[@]}"; do
    if [ ! -s distfiles/"${BASH_PATCH_DIR}/${patch}" ]; then
      echo -e "${TOMATO}= ERROR: patch file missing after download: ${patch}${NC}"
      exit 1
    fi
  done
  printf '%s\n' "${BASH_PATCH_FILES[@]}" > distfiles/"${BASH_PATCH_DIR}/.patch-list"
}

download_bash_upstream_patches
run_build_setup "bash" "${BASH_VERSION}" "${BASH_TARBALL}" \
  -- "${BASH_MIRRORS[@]}"
cp -r distfiles/"${BASH_PATCH_DIR}" "./${CHROOTDIR}/"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
echo -e "${ORANGE}= Installing dependencies...${NC}"
apk update && apk add build-base mold ccache sed automake autoconf pkgconfig ncurses-dev ncurses-static perl gettext-dev gettext-static readline readline-static
apk upgrade musl-dev mold --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache && export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
echo -e "${LIME}= Extracting source${NC}"
tar xf ${BASH_TARBALL}
cd bash-${BASH_VERSION}/
while read -r patch; do
  echo -e "${NAVAJO}= applying \$patch${NC}"
  patch -p0 < ../${BASH_PATCH_DIR}/"\$patch"
done < ../${BASH_PATCH_DIR}/.patch-list
if [ -d ../patches ]; then
   # Check if directory is not empty
   if [ "\$(ls -A ../patches 2>/dev/null)" ]; then
       echo -e "${NEONPINK}= Applying custom patch(es)${NC}"
       for p in ../patches/*; do
           if [ -f "\$p" ]; then
               echo -e "${NEONBLUE}Applying \$(basename "\$p")...${NC}"
               patch -p1 --fuzz=4 < "\$p"
           fi
       done
   fi
fi
echo -e "${PEACH}= Configure source${NC}"
./configure \
  --disable-nls --without-bash-malloc --with-curses --enable-static-link \
  LDFLAGS='${BLDFLAGS} ${MOLD} ${LPIE}' PKG_CONFIG='${PKGCFG}' \
  CFLAGS='${BCFLAGS} ${ARCH_FLAGS} ${EXTRA} ${LTO} ${CPIE} -Wno-discarded-qualifiers'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "\n${CARIBBEAN}= ccache statistics:${NC}"
ccache -s | tail -n 10
EOF

package_output "bash" "./${CHROOTDIR}/bash-${BASH_VERSION}/bash"
