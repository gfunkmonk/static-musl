#!/usr/bin/env bash
# Fetches latest versions and updates common.sh constants
cd "$(dirname "$0")/.."

source $(pwd)/common.sh
VERSIONS=$($(pwd)/scripts/get_versions.sh | grep ": " | sed 's/\x1b\[[0-9;]*m//g')

while read -r line; do
  tool=$(echo "$line" | cut -d: -f1 | tr '[:lower:]' '[:upper:]')
  ver=$(echo "$line" | cut -d: -f2 | xargs)
  sed -i "s/FALLBACK_${tool}=\".*\"/FALLBACK_${tool}=\"${ver}\"/" $(pwd)/config.sh
done <<< "$VERSIONS"