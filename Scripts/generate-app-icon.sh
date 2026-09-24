#!/bin/zsh
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
icon_set="$repo_root/Nebby/Assets.xcassets/AppIcon.appiconset"
master="$icon_set/NebbyAppIcon-1024.png"
mkdir -p "$icon_set"

magick -background none -density 384 "$repo_root/Design/NebbyAppIcon.svg" \
  -resize 1024x1024 PNG32:"$master"

for size in 16 32 64 128 256 512; do
  magick "$master" -filter Lanczos -resize "${size}x${size}" \
    PNG32:"$icon_set/NebbyAppIcon-${size}.png"
done
