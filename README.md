# static-musl-builds

Build scripts that produce fully static, multi-architecture binaries using musl libc and Alpine Linux.

## Tools

| Tool | Version | Description |
|------|---------|-------------|
| 7zz | v1.5.7-R4 | CLI 7zip built from 7-Zip-zstd |
| aria2c | latest | Multi-protocol download utility |
| axel | latest | Parallel download accelerator |
| bash | 5.3 | Bash (Bourne Again SHell) |
| bsdtar | latest | Archive tool (libarchive) |
| curl | latest | Data transfer tool |
| dash | 0.5.13.2 | POSIX shell |
| gawk | 5.4.0 | a tool for processing text data |
| htop | latest | Interactive process viewer |
| less | latest | pager program similar to more |
| lftp | latest | Command line ftp client |
| nano | 8.7.1 | Small command-line text editor |
| nmap | 7.98 | Network scanning & discovery tool |
| oksh | latest | OpenBSD ksh shell |
| openssh | 10.2p1 | OpenSSH ssh client |
| pigz | latest | Parallel implementation of GZip |
| sed | 4.9 | Stream editor for filtering/transforming text |
| screen | 5.0.1 | Screen is a mature terminal multiplexer |
| socat | 1.8.1.1 | Socat is a flexible, multi-purpose relay tool |
| tar | 1.35 | GNU tar archive utility |
| tmux | latest | Tmux is a terminal multiplexer |
| upx | latest | UPX w/ custom patch & zstd support |
| vim | latest | Text editor |
| wget | 1.25.0 | File downloader |
| xz | latest | XZ/LZMA compression |
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
