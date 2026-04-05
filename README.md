# static-musl-builds
 
Build scripts that produce fully static, multi-architecture binaries using musl libc and Alpine Linux.

## Tools

| Tool | Version | Description |
|:-----:|:---------:|:-------------|
| 7zz | latest | CLI 7zip built from 7-Zip-zstd |
| aria2c | latest | Multi-protocol download utility |
| axel | latest | Parallel download accelerator |
| bash | latest | Bash (Bourne Again SHell) |
| bsdtar | latest | Archive tool (libarchive) |
| curl | latest | Data transfer tool |
| dash | latest | POSIX shell |
| dropbear | latest | A relatively small SSH server and client. |
| fping | latest | A fancy ping tool |
| gawk | latest | a tool for processing text data |
| hexcurse | latest | ncurses based hex editor |
| htop | latest | Interactive process viewer |
| less | latest | pager program similar to more |
| lftp | latest | Command line ftp client |
| nano | latest | Small command-line text editor |
| netcat | latest | TCP/IP Swiss Army knife |
| nmap | latest | Network scanning & discovery tool |
| oksh | latest | OpenBSD ksh shell |
| openssh | latest | OpenSSH ssh client |
| pigz | latest | Parallel implementation of GZip |
| ripgrep | latest | a line-oriented recursive search tool |
| rsync | latest | rsync synchronizes files locally or remotely |
| sed | latest | Stream editor for filtering/transforming text |
| screen | latest | Screen is a mature terminal multiplexer |
| socat | latest | Socat is a flexible, multi-purpose relay tool |
| tar | latest | GNU tar archive utility |
| tnftp | latest | a port of the NetBSD FTP client |
| tmux | latest | Tmux is a terminal multiplexer |
| upx | latest | UPX w/ custom patch & zstd support |
| vim | latest | Text editor |
| wget | latest | File downloader |
| wget2 | latest | The successor of GNU Wget. |
| xz | latest | XZ/LZMA compression |
| zsh | latest | an interactive Bourne-like POSIX shell |
| zstd | latest | Fast real-time compression algorithm |

## Architectures

`x86_64` · `x86` · `aarch64` · `armv7` · `armhf`

## Usage

```bash
# Build for host architecture
./curl-static-musl.sh

# Build for a specific architecture
ARCH=aarch64 ./curl-static-musl.sh
```

Output binaries are written to `dist/` as `<tool>-<version>-<arch>.tar.xz`.

## Structure

```
.
├── common.sh               # Shared functions sourced by all build scripts
├── *-static-musl.sh        # Per-tool build scripts
├── patches/                # Patch files applied during builds
└── .github/workflows/
    └── build-all.yml       # CI: builds all tools × all architectures
```

## CI

The workflow in `.github/workflows/build-all.yml` builds all tools for all
architectures on a schedule (every 6 days) and publishes releases tagged with
the specific tool version (e.g., `bash-5.3`).
