#!/usr/bin/env bash

cd "$(dirname "$0")/.."
source "$(dirname "$0")/../common.sh"

GREEN="\033[1;32m"
BWHITE="\033[1;37m"

SEVENZIP_VER=$(get_version release "mcmilk/7-Zip-zstd" "")
echo -e "${BWHITE}7zz: ${GREEN}${SEVENZIP_VER}${NC}"

ARIA2_VER=$(get_version release "aria2/aria2" '.tag_name | ltrimstr("release-")' "")
echo -e "${BWHITE}aria2: ${GREEN}${ARIA2_VER}${NC}"

AXEL_VER=$(get_version release "axel-download-accelerator/axel" '.tag_name | ltrimstr("v")' "")
echo -e "${BWHITE}axel: ${GREEN}${AXEL_VER}${NC}"

BASH_VER=$(get_git_version "https://cgit.git.savannah.gnu.org/cgit/bash.git/refs/tags" "bash-[0-9]+\.[0-9]+(\.[0-9]+)*" "bash-" "")
echo -e "${BWHITE}bash: ${GREEN}${BASH_VER}${NC}"

BSDTAR_VER=$(get_version release "libarchive/libarchive" '.tag_name | ltrimstr("v")' "")
echo -e "${BWHITE}bsdtar: ${GREEN}${BSDTAR_VER}${NC}"

CURL_VER=$(get_version release "curl/curl" '.tag_name | ltrimstr("curl-") | gsub("_"; ".")' "")
echo -e "${BWHITE}curl: ${GREEN}${CURL_VER}${NC}"

DASH_VER=$(get_git_version "https://git.kernel.org/pub/scm/utils/dash/dash.git/refs/tags" "v[0-9]+\.[0-9]+(\.[0-9]+)*" "v" "")
echo -e "${BWHITE}dash: ${GREEN}${DASH_VER}${NC}"

DROPBEAR_VER=$(get_version release "mkj/dropbear" '.tag_name | ltrimstr("DROPBEAR_")' "")
echo -e "${BWHITE}dropbear: ${GREEN}${DROPBEAR_VER}${NC}"

GAWK_VER=$(get_git_version "https://cgit.git.savannah.gnu.org/cgit/gawk.git/refs/tags" "[0-9]+\.[0-9]+(\.[0-9]+)*" "gawk-" "")
echo -e "${BWHITE}gawk: ${GREEN}${GAWK_VER}${NC}"

HTOP_VER=$(get_version release "htop-dev/htop" "" "")
echo -e "${BWHITE}htop: ${GREEN}${HTOP_VER}${NC}"

LESS_VER=$(get_version tag "gwsw/less" '.[0].name | ltrimstr("v")' "")
echo -e "${BWHITE}less: ${GREEN}${LESS_VER}${NC}"

LFTP_VER=$(get_version release "lavv17/lftp" '.tag_name | ltrimstr("v")' "")
echo -e "${BWHITE}lftp: ${GREEN}${LFTP_VER}${NC}"

NANO_VER=$(get_git_version "https://cgit.git.savannah.gnu.org/cgit/nano.git/refs/tags" "v[0-9]+\.[0-9]+(\.[0-9]+)*" "v" "")
echo -e "${BWHITE}nano: ${GREEN}${NANO_VER}${NC}"

FPING_VER=$(get_version release "schweikert/fping" '.tag_name | ltrimstr("v")' "")
echo -e "${BWHITE}fping: ${GREEN}${FPING_VER}${NC}"

NETCAT_VER=$("${CURL}" -s "https://salsa.debian.org/api/v4/projects/debian%2Fnetcat-openbsd/repository/tags" | \
  "${JQ}" -r '[.[] | select(.name | test("^[0-9]"))] | .[0].name // empty' 2>/dev/null)
echo -e "${BWHITE}netcat: ${GREEN}${NETCAT_VER}${NC}"

NMAP_VER=$("${CURL}" -s https://nmap.org/dist/ | grep -o 'href="[^"]*.tar.bz2"' | cut -d'"' -f2 | sort | tail -1 | sed 's/\.tar.*//' | sed 's/nm
echo -e "${BWHITE}nmap: ${GREEN}${NMAP_VER}${NC}"

OKSH_VER=$(get_version release "ibara/oksh" '.tag_name | ltrimstr("oksh-")' "")
echo -e "${BWHITE}oksh: ${GREEN}${OKSH_VER}${NC}"

OPENSSH_VER=$(get_git_version "https://anongit.mindrot.org/openssh.git/refs/tags" "V_[0-9]+_[0-9]+(_P[0-9]+)?" "V_" "")
echo -e "${BWHITE}openssh: ${GREEN}${OPENSSH_VER}${NC}"

PIGZ_VER=$(get_version tag "madler/pigz" '.[0].name | ltrimstr("v")' "")
echo -e "${BWHITE}pigz: ${GREEN}${PIGZ_VER}${NC}"

#SCREEN_VER=$(get_git_version "https://cgit.git.savannah.gnu.org/cgit/screen.git/refs/tags" "[0-9]+\.[0-9]+(\.[0-9]+)*" "v" "")
SCREEN_VER=$("${CURL}" -s https://ftp.gnu.org/gnu/screen/ | grep -oP 'screen-\K[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -n 1)
echo -e "${BWHITE}screen: ${GREEN}${SCREEN_VER}${NC}"

SED_VER=$(get_git_version "https://cgit.git.savannah.gnu.org/cgit/sed.git/refs/tags" "[0-9]+\.[0-9]+(\.[0-9]+)*" "v" "")
echo -e "${BWHITE}sed: ${GREEN}${SED_VER}${NC}"

SOCAT_VER=$(get_git_version "https://repo.or.cz/socat.git" "refs/tags/tag-1\.[0-9]+\.[0-9]+(\.[0-9]+)*" "refs/tags/tag-" "")
echo -e "${BWHITE}socat: ${GREEN}${SOCAT_VER}${NC}"

TAR_VER=$(get_git_version "https://cgit.git.savannah.gnu.org/cgit/tar.git/refs/tags" "v[0-9]+\.[0-9]+(\.[0-9]+)*" "v" "")
echo -e "${BWHITE}tar: ${GREEN}${TAR_VER}${NC}"

TMUX_VER=$(get_version release "tmux/tmux" ".tag_name" "")
echo -e "${BWHITE}tmux: ${GREEN}${TMUX_VER}${NC}"

TNFTP_VER=$("${CURL}" -s https://ftp.netbsd.org/pub/NetBSD/misc/tnftp/ | grep -o 'href="tnftp-[^"]*.gz"' | cut -d'"' -f2 | sort | tail -1 | sed ed 's/tnftp-//')
echo -e "${BWHITE}tnftp: ${GREEN}${TNFTP_VER}${NC}"

RG_VER=$(get_version release "BurntSushi/ripgrep" '.tag_name | ltrimstr("v")' "")
echo -e "${BWHITE}ripgrep: ${GREEN}${RG_VER}${NC}"

UPX_VER=$(get_version release "upx/upx" '.tag_name | ltrimstr("v")' "")
echo -e "${BWHITE}upx: ${GREEN}${UPX_VER}${NC}"

VIM_VER=$(get_version tag "vim/vim" '.[0].name | ltrimstr("v")' "")
echo -e "${BWHITE}vim: ${GREEN}${VIM_VER}${NC}"

WGET_VER=$(get_git_version "https://cgit.git.savannah.gnu.org/cgit/wget.git/refs/tags" "v[0-9]+\.[0-9]+(\.[0-9]+)*" "v" "")
echo -e "${BWHITE}wget: ${GREEN}${WGET_VER}${NC}"

WGET2_VER=$(get_version release "rockdaboot/wget2" '.tag_name | ltrimstr("v")' "")
echo -e "${BWHITE}wget2: ${GREEN}${WGET2_VER}${NC}"

XZ_VER=$(get_version release "tukaani-project/xz" '.tag_name | ltrimstr("v")' "")
echo -e "${BWHITE}xz: ${GREEN}${XZ_VER}${NC}"

ZSH_VER=$("${CURL}" -s https://www.zsh.org/pub/ | grep -o 'href="[^"]*.xz"' | grep -e zsh-[0-9] | cut -d'"' -f2 | sort | tail -1 | sed 's/\.tar.zsh-//g')
echo -e "${BWHITE}zsh: ${GREEN}${ZSH_VER}${NC}"

ZSTD_VER=$(get_version release "facebook/zstd" '.tag_name | ltrimstr("v")' "")
echo -e "${BWHITE}zstd: ${GREEN}${ZSTD_VER}${NC}"
