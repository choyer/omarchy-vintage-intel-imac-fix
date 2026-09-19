#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
version=${1:?Usage: prepare-release.sh VERSION}
uki="$root/boot/omarchy-imac-radeon-fix.efi"
pkg="$root/dist/hyprland-0.56.2-2.1-x86_64.pkg.tar.zst"
[[ -f "$pkg" ]] || pkg="$root/packages/hyprland-0.56.2-2.1-x86_64.pkg.tar.zst"
[[ -s "$uki" ]] || { echo "Missing $uki; build the UKI first." >&2; exit 1; }
[[ -n "$pkg" ]] || { echo 'No Hyprland package in dist/ or packages/.' >&2; exit 1; }
mkdir -p "$root/releases/$version"
cp "$uki" "$root/releases/$version/"
cp "$pkg" "$root/releases/$version/"
cp "$root/install-omarchy-radeon-imac-fix.sh" "$root/uninstall-omarchy-radeon-imac-fix.sh" "$root/README.md" "$root/manifest.json" "$root/releases/$version/"
cp -a "$root/tools" "$root/patches" "$root/hyprland" "$root/releases/$version/"
release_dir="$root/releases/$version"
(cd "$release_dir" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum) > "$release_dir/SHA256SUMS"
archive="$root/omarchy-vintage-intel-imac-fix-$version.tar.zst"
sha_file="$archive.sha256"
tar -C "$root/releases" -caf "$archive" "$version"
(cd "$(dirname "$archive")" && sha256sum "$(basename "$archive")") > "$sha_file"

if [[ -n ${SUDO_USER:-} && ${SUDO_USER:-} != root ]]; then
  owner_uid=$(id -u "$SUDO_USER")
  owner_gid=$(id -g "$SUDO_USER")
  chown -R "$owner_uid:$owner_gid" "$release_dir" "$archive" "$sha_file"
fi
echo "Created release archive: $archive"
