#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/common.sh"

BASH_VERSION="5.3"
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
  "bash-aliases-repeat.patch" \
  "bash-bash-config.patch" \
  "bash-bashansi-bool-c23.patch" \
  "bash-default-editor.patch" \
  "bash-input-err.patch" \
  "bash_cd_three_dot.patch" \
  "bash_make-the-bash-fc-builtin-more-reliable-for-scripting.patch" \
  -- "${BASH_MIRRORS[@]}"
cp -r distfiles/"${BASH_PATCH_DIR}" "./${CHROOTDIR}/"

sudo chroot "./${CHROOTDIR}/" /bin/sh -s <<EOF
set -e
apk update
apk add build-base ccache sed automake autoconf pkgconfig ncurses-dev ncurses-static perl gettext-dev gettext-static readline readline-static
apk upgrade musl-dev --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main
mkdir -p /ccache
export CCACHE_DIR=${CCACHE_CHROOT_DIR} CCACHE_BASEDIR=/ PATH=/usr/lib/ccache/bin:\$PATH
chmod 755 upx
echo -e "${LIME}= Extracting source${NC}"
tar xf ${BASH_TARBALL}
cd bash-${BASH_VERSION}/
while read -r patch; do
  echo -e "${NAVAJO}= applying \$patch${NC}"
  patch -p0 < ../${BASH_PATCH_DIR}/"\$patch"
done < ../${BASH_PATCH_DIR}/.patch-list
echo -e "${BOYSENBERRY}= applying custom patch${NC}"
#patch -p1 --fuzz=4 < ../bash.patch
patch -p1 --fuzz=4 < ../bash-aliases-repeat.patch
patch -p1 --fuzz=4 < ../bash-bash-config.patch
patch -p1 --fuzz=4 < ../bash-bashansi-bool-c23.patch
patch -p1 --fuzz=4 < ../bash-default-editor.patch
patch -p1 --fuzz=4 < ../bash-input-err.patch
patch -p1 --fuzz=4 < ../bash_cd_three_dot.patch
patch -p1 --fuzz=4 < ../bash_make-the-bash-fc-builtin-more-reliable-for-scripting.patch
echo -e "${PEACH}= Configure source${NC}"
./configure \
  --disable-nls --without-bash-malloc --with-curses --enable-static-link \
  LDFLAGS='${BASE_LDFLAGS} -w -Wl,-s' PKG_CONFIG='${BASE_PKGCFG}' \
  CFLAGS='${BASE_CFLAGS} ${ARCH_FLAGS} ${EXTRA_CFLAGS} ${LTOFLAGS} -Wno-discarded-qualifiers'
echo -e "${VIOLET}= Building...${NC}"
make -j\$(nproc)
echo -e "${CHARTREUSE}= Stripping binary${NC}"
strip bash
echo -e "${PURPLE_BLUE}= Compressing with UPX${NC}"
../upx --lzma bash
EOF

package_output "bash" "${CHROOTDIR}/bash-${BASH_VERSION}/bash"
