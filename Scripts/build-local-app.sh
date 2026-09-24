#!/bin/zsh
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
derived_data="${TMPDIR:-/tmp}/NebbyLocalReleaseDerivedData"

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
  xcodebuild -project "$repo_root/Nebby.xcodeproj" \
  -scheme Nebby -configuration Release -destination 'platform=macOS' \
  -derivedDataPath "$derived_data" CODE_SIGN_IDENTITY=- build

mkdir -p "$repo_root/dist"
rm -rf "$repo_root/dist/Nebby.app"
ditto "$derived_data/Build/Products/Release/Nebby.app" "$repo_root/dist/Nebby.app"
codesign --verify --strict --verbose=2 "$repo_root/dist/Nebby.app"
echo "$repo_root/dist/Nebby.app"
