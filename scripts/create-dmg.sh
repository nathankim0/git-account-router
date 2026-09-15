#!/bin/sh

set -eu

version=${1:-0.1.0}
repo_dir=$(cd "$(dirname "$0")/.." && pwd)
dist_dir="$repo_dir/dist"
app_path="$dist_dir/Git Account Router.app"
staging="$dist_dir/dmg-root"
dmg_path="$dist_dir/GitAccountRouter-$version.dmg"

case "$staging" in
  "$repo_dir"/dist/dmg-root) ;;
  *) printf 'Unsafe staging path: %s\n' "$staging" >&2; exit 1 ;;
esac

"$repo_dir/scripts/build-release.sh" "$version" >/dev/null
rm -rf "$staging"
rm -f "$dmg_path"
mkdir -p "$staging"
cp -R "$app_path" "$staging/"
ln -s /Applications "$staging/Applications"

diskutil image create from \
  --volumeName "Git Account Router" \
  --format UDZO \
  "$staging" \
  "$dmg_path" >/dev/null
hdiutil verify "$dmg_path" >/dev/null
rm -rf "$staging"

printf '%s\n' "$dmg_path"
