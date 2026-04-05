#!/bin/bash
# toggle-pie.sh — Switch all build scripts between -static-pie and -no-pie.
#
# Usage:
#   ./scripts/toggle-pie.sh --pie      # enable static-pie / -fPIE
#   ./scripts/toggle-pie.sh --no-pie   # disable PIE (default)

set -euo pipefail

MODE="${1:---no-pie}"

case "${MODE}" in
  --pie)
    OLD_LDPIE="-no-pie"
    NEW_LDPIE="-static-pie"
    OLD_FPIE="-fno-PIE"
    NEW_FPIE="-fPIE"
    OLD_FPIE_LOWER="-fno-pie"
    NEW_FPIE_LOWER="-fpie"
    echo "Switching build scripts to static-pie / -fPIE ..."
    ;;
  --no-pie)
    OLD_LDPIE="-static-pie"
    NEW_LDPIE="-no-pie"
    OLD_FPIE="-fPIE"
    NEW_FPIE="-fno-PIE"
    OLD_FPIE_LOWER="-fpie"
    NEW_FPIE_LOWER="-fno-pie"
    echo "Switching build scripts to no-pie / -fno-PIE ..."
    ;;
  *)
    echo "Usage: $0 [--pie|--no-pie]" >&2
    exit 1
    ;;
esac

# Run from the repo root regardless of where the script lives
cd "$(dirname "$0")/.."

for file in *-static-musl.sh; do
  sed -i \
    -e "s|${OLD_LDPIE}|${NEW_LDPIE}|g" \
    -e "s|${OLD_FPIE}|${NEW_FPIE}|g" \
    -e "s|${OLD_FPIE_LOWER}|${NEW_FPIE_LOWER}|g" \
    "$file"
done

echo "Done. $(ls *-static-musl.sh | wc -l) files updated."