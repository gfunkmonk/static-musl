#!/usr/bin/env bash

cd "$(dirname "$0")/.."
source "$(dirname "$0")/../common.sh"

RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
PURPLE="\033[1;35m"
BWHITE="\033[1;37m"

echo -e "${PURPLE}#################################################################${NC}"
echo -e "${GREEN}Green${BWHITE} = Pulled from github/gitlab/other git${NC}"
echo -e "${RED}Red${BWHITE} = Fallback used${NC}"
echo -e "${YELLOW}Yellow${BWHITE} = Other method (curl dist folder, etc)${NC}"
echo -e "${PURPLE}#################################################################${NC}"
echo -e "\n"

SEVENZIP_VER=${GREEN}$(get_version release "mcmilk/7-Zip-zstd" "" "${RED}FALLBACK${NC}")
echo -e "${BWHITE}7zz: ${SEVENZIP_VER}${NC}"

ARIA2_VER=${GREEN}$(get_version release "aria2/aria2" '.tag_name | ltrimstr("release-")' "${RED}FALLBACK${NC}")
echo -e "${BWHITE}aria2: ${ARIA2_VER}${NC}"

AXEL_VER=${GREEN}$(get_version release "axel-download-accelerator/axel" '.tag_name | ltrimstr("v")' "${RED}FALLBACK${NC}")
echo -e "${BWHITE}axel: ${AXEL_VER}${NC}"

BASH_VER=${GREEN}$(get_git_version "https://cgit.git.savannah.gnu.org/cgit/bash.git/refs/tags" "bash-[0-9]+\.[0-9]+(\.[0-9]+)*" "bash-" "${RED}FALLBACK${NC}")
echo -e "${BWHITE}bash: ${BASH_VER}${NC}"

BSDTAR_VER=${GREEN}$(get_version release "libarchive/libarchive" '.tag_name | ltrimstr("v")' "${RED}FALLBACK${NC}")
echo -e "${BWHITE}bsdtar: ${BSDTAR_VER}${NC}"

CURL_VER=${GREEN}$(get_version release "curl/curl" '.tag_name | ltrimstr("curl-") | gsub("_"; ".")' "${RED}FALLBACK${NC}")
echo -e "${BWHITE}curl: ${CURL_VER}${NC}"

DASH_VER=${GREEN}$(get_git_version "https://git.kernel.org/pub/scm/utils/dash/dash.git/refs/tags" "v[0-9]+\.[0-9]+(\.[0-9]+)*" "v" "${RED}FALLBACK${NC}")
echo -e "${BWHITE}dash: ${DASH_VER}${NC}"

DROPBEAR_VER=${GREEN}$(get_version release "mkj/dropbear" '.tag_name | ltrimstr("DROPBEAR_")' "${RED}FALLBACK${NC}")
echo -e "${BWHITE}dropbear: ${DROPBEAR_VER}${NC}"

FPING_VER=${GREEN}$(get_version release "schweikert/fping" '.tag_name | ltrimstr("v")' "${RED}FALLBACK${NC}")
echo -e "${BWHITE}fping: ${FPING_VER}${NC}"

#GAWK_VER=${GREEN}$(get_git_version "https://cgit.git.savannah.gnu.org/cgit/gawk.git/refs/tags" "[0-9]+\.[0-9]+(\.[0-9]+)*" "gawk-" "${RED}FALLBACK${NC}")
GAWK_VER=${YELLOW}$("${CURL}" -s https://ftp.gnu.org/gnu/gawk/ | grep -oP 'gawk-\K[0-9]+\.[0-9]+(\.[0-9]+)?' | sort -V | tail -n 1)
echo -e "${BWHITE}gawk: ${GAWK_VER}${NC}"

HEXCURSE_VER=${GREEN}$(get_version release "prso/hexcurse-ng" '.tag_name | ltrimstr("v")' "${RED}FALLBACK${NC}")
echo -e "${BWHITE}hexcurse: ${HEXCURSE_VER}${NC}"

HTOP_VER=${GREEN}$(get_version release "htop-dev/htop" "" "${RED}FALLBACK${NC}")
echo -e "${BWHITE}htop: ${HTOP_VER}${NC}"

LESS_VER=${GREEN}$(get_version tag "gwsw/less" '.[0].name | ltrimstr("v")' "${RED}FALLBACK${NC}")
echo -e "${BWHITE}less: ${LESS_VER}${NC}"

LFTP_VER=${GREEN}$(get_version release "lavv17/lftp" '.tag_name | ltrimstr("v")' "${RED}FALLBACK${NC}")
echo -e "${BWHITE}lftp: ${LFTP_VER}${NC}"

MC_VER=${YELLOW}$("${CURL}" -s https://ftp.osuosl.org/pub/midnightcommander/ | grep -oP 'mc-\K[0-9]+\.[0-9]+(\.[0-9]+)?' | sort -V | tail -n 1)
echo -e "${BWHITE}mc: ${MC_VER}${NC}"

#NANO_VER=${GREEN}$(get_git_version "https://cgit.git.savannah.gnu.org/cgit/nano.git/refs/tags" "v[0-9]+\.[0-9]+(\.[0-9]+)*" "v" "${RED}FALLBACK${NC}")
NANO_VER=${YELLOW}$("${CURL}" -s https://ftp.gnu.org/gnu/nano/ | grep -oP 'nano-\K[0-9]+\.[0-9]+(\.[0-9]+)?' | sort -V | tail -n 1)
echo -e "${BWHITE}nano: ${NANO_VER}${NC}"

NETCAT_VER=${YELLOW}$("${CURL}" -s "https://salsa.debian.org/api/v4/projects/debian%2Fnetcat-openbsd/repository/tags?per_page=20" | \
  "${JQ}" -r '[.[] | select(.name | test("^debian/"))] | .[0].name | ltrimstr("debian/")' 2>/dev/null)
echo -e "${BWHITE}netcat: ${NETCAT_VER}${NC}"

NMAP_VER=${YELLOW}$("${CURL}" -s https://nmap.org/dist/ | grep -o 'href="[^"]*.tar.bz2"' | cut -d'"' -f2 | sort | tail -1 | sed 's/\.tar.*//' | sed 's/nmap-//g')
echo -e "${BWHITE}nmap: ${NMAP_VER}${NC}"

OKSH_VER=${GREEN}$(get_version release "ibara/oksh" '.tag_name | ltrimstr("oksh-")' "${RED}FALLBACK${NC}")
echo -e "${BWHITE}oksh: ${OKSH_VER}${NC}"

OPENSSH_VER=${GREEN}$(get_git_version "https://anongit.mindrot.org/openssh.git/refs/tags" "V_[0-9]+_[0-9]+(_P[0-9]+)?" "V_" "${RED}FALLBACK${NC}")
echo -e "${BWHITE}openssh: ${OPENSSH_VER}${NC}"

PIGZ_VER=${GREEN}$(get_version tag "madler/pigz" '.[0].name | ltrimstr("v")' "${RED}FALLBACK${NC}")
echo -e "${BWHITE}pigz: ${PIGZ_VER}${NC}"

RG_VER=${GREEN}$(get_version release "BurntSushi/ripgrep" '.tag_name | ltrimstr("v")' "${RED}FALLBACK${NC}")
echo -e "${BWHITE}ripgrep: ${RG_VER}${NC}"

RSYNC_VER=${GREEN}$(get_version release "RsyncProject/rsync" '.tag_name | ltrimstr("v")' "${RED}FALLBACK${NC}")
echo -e "${BWHITE}rsync: ${RSYNC_VER}${NC}"

SCREEN_VER=${GREEN}$(get_git_version "https://cgit.git.savannah.gnu.org/cgit/screen.git/refs/tags" "[0-9]+\.[0-9]+(\.[0-9]+)*" "v" "${RED}FALLBACK${NC}")
#SCREEN_VER=${YELLOW}$("${CURL}" -s https://ftp.gnu.org/gnu/screen/ | grep -oP 'screen-\K[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -n 1)
echo -e "${BWHITE}screen: ${SCREEN_VER}${NC}"

#SED_VER=${GREEN}$(get_git_version "https://cgit.git.savannah.gnu.org/cgit/sed.git/refs/tags" "[0-9]+\.[0-9]+(\.[0-9]+)*" "v" "${RED}FALLBACK${NC}")
SED_VER=${YELLOW}$("${CURL}" -s https://ftp.gnu.org/gnu/sed/ | grep -oP 'sed-\K[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -n 1)
#SED_VER=${GREEN}$(get_version tag "mirror/sed" '.[0].name | ltrimstr("v")' "${RED}FALLBACK${NC}")
echo -e "${BWHITE}sed: ${SED_VER}${NC}"

SOCAT_VER=${GREEN}$(get_git_version "https://repo.or.cz/socat.git/refs/tags" "tag-1\.[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)*" "tag-" "${RED}FALLBACK${NC}")
echo -e "${BWHITE}socat: ${SOCAT_VER}${NC}"

#TAR_VER=${GREEN}$(get_git_version "https://cgit.git.savannah.gnu.org/cgit/tar.git/refs/tags" "v[0-9]+\.[0-9]+(\.[0-9]+)*" "v" "${RED}FALLBACK${NC}")
TAR_VER=${YELLOW}$("${CURL}" -s https://ftp.gnu.org/gnu/tar/ | grep -oP 'tar-\K[0-9]+\.[0-9]+(\.[0-9]+)?' | sort -V | tail -n 1)
echo -e "${BWHITE}tar: ${TAR_VER}${NC}"

TMUX_VER=${GREEN}$(get_version release "tmux/tmux" ".tag_name" "${RED}FALLBACK${NC}")
echo -e "${BWHITE}tmux: ${TMUX_VER}${NC}"

TNFTP_VER=${YELLOW}$("${CURL}" -s https://ftp.netbsd.org/pub/NetBSD/misc/tnftp/ | grep -o 'href="tnftp-[^"]*.gz"' | cut -d'"' -f2 | sort | tail -1 | sed 's/\..*//' | sed 's/tnftp-//')
echo -e "${BWHITE}tnftp: ${TNFTP_VER}${NC}"

UPX_VER=${GREEN}$(get_version release "upx/upx" '.tag_name | ltrimstr("v")' "${RED}FALLBACK${NC}")
echo -e "${BWHITE}upx: ${UPX_VER}${NC}"

VIM_VER=${GREEN}$(get_version tag "vim/vim" '.[0].name | ltrimstr("v")' "${RED}FALLBACK${NC}")
echo -e "${BWHITE}vim: ${VIM_VER}${NC}"

#WGET_VER=${GREEN}$(get_git_version "https://cgit.git.savannah.gnu.org/cgit/wget.git/refs/tags" "v[0-9]+\.[0-9]+(\.[0-9]+)*" "v" "${RED}FALLBACK${NC}")
WGET_VER=${GREEN}$(get_gitlab_version "gnuwget/wget" "${RED}FALLBACK${NC}")
echo -e "${BWHITE}wget: ${WGET_VER}${NC}"

#WGET2_VER=${GREEN}$(get_version release "rockdaboot/wget2" '.tag_name | ltrimstr("v")' "${RED}FALLBACK${NC}")
WGET2_VER=${GREEN}$(get_gitlab_version "gnuwget/wget2" "${RED}FALLBACK${NC}")
echo -e "${BWHITE}wget2: ${WGET2_VER}${NC}"

XZ_VER=${GREEN}$(get_version release "tukaani-project/xz" '.tag_name | ltrimstr("v")' "${RED}FALLBACK${NC}")
echo -e "${BWHITE}xz: ${XZ_VER}${NC}"

ZSH_VER=${YELLOW}$("${CURL}" -s https://www.zsh.org/pub/ | grep -o 'href="[^"]*.xz"' | grep -e zsh-[0-9] | cut -d'"' -f2 | sort | tail -1 | sed 's/\.tar.*//' | sed 's/zsh-//g')
echo -e "${BWHITE}zsh: ${ZSH_VER}${NC}"

ZSTD_VER=${GREEN}$(get_version release "facebook/zstd" '.tag_name | ltrimstr("v")' "${RED}FALLBACK${NC}")
echo -e "${BWHITE}zstd: ${ZSTD_VER}${NC}"
