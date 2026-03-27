#!/bin/bash

for file in *-static-musl.sh; do
  sed -i 's|-static-pie|-no-pie|g' "$file"
done
for file in *-static-musl.sh; do
  sed -i 's|-fPIE|-fno-PIE|g' "$file"
done
for file in *-static-musl.sh; do
  sed -i 's|-fpie|-fno-pie|g' "$file"
done

