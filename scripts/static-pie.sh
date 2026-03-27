#!/bin/bash

for file in *-static-musl.sh; do
  sed -i 's|-no-pie|-static-pie|g' "$file"
done
for file in *-static-musl.sh; do
  sed -i 's|-fno-PIE|-fPIE|g' "$file"
done
for file in *-static-musl.sh; do
  sed -i 's|-fno-pie|-fpie|g' "$file"
done