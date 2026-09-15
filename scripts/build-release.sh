#!/bin/sh

set -eu

version=${1:-0.1.0}
build_number=${BUILD_NUMBER:-1}
repo_dir=$(cd "$(dirname "$0")/.." && pwd)
dist_dir="$repo_dir/dist"
app_path="$dist_dir/Git Account Router.app"
contents="$app_path/Contents"
iconset="$dist_dir/AppIcon.iconset"

case "$dist_dir" in
  "$repo_dir"/dist) ;;
  *) printf 'Unsafe dist path: %s\n' "$dist_dir" >&2; exit 1 ;;
esac

rm -rf "$app_path" "$iconset"
mkdir -p "$contents/MacOS" "$contents/Resources" "$iconset"

swift build --package-path "$repo_dir" -c release --product GitAccountRouter
swift build --package-path "$repo_dir" -c release --product git-account-status
bin_dir=$(swift build --package-path "$repo_dir" -c release --show-bin-path)

cp "$bin_dir/GitAccountRouter" "$contents/MacOS/GitAccountRouter"
cp "$bin_dir/git-account-status" "$contents/Resources/git-account-status"
cp "$repo_dir/assets/app-icon.png" "$contents/Resources/AppIcon.png"

resource_bundle="$bin_dir/GitAccountRouter_GitAccountRouter.bundle"
if [ -d "$resource_bundle" ]; then
  cp -R "$resource_bundle" "$contents/Resources/"
fi

sed \
  -e "s/@VERSION@/$version/g" \
  -e "s/@BUILD@/$build_number/g" \
  "$repo_dir/Sources/GitAccountRouter/Resources/Info.plist.in" >"$contents/Info.plist"

make_icon() {
  size=$1
  output=$2
  sips -z "$size" "$size" "$repo_dir/assets/app-icon.png" --out "$iconset/$output" >/dev/null
}

make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
make_icon 1024 icon_512x512@2x.png
iconutil -c icns "$iconset" -o "$contents/Resources/AppIcon.icns"

chmod 755 "$contents/MacOS/GitAccountRouter" "$contents/Resources/git-account-status"
codesign --force --deep --sign - "$app_path"
codesign --verify --deep --strict --verbose=2 "$app_path"

printf '%s\n' "$app_path"
