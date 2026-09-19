#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
krel=${KERNEL_RELEASE:-$(uname -r)}
version=${LINUX_VERSION:-7.2.5}
sha=55ddf0df8325d9dad96fcff7bd93977d22e3f50af06527572af59b77c7632b78
headers=/usr/lib/modules/$krel/build
[[ -d $headers ]] || { echo "Missing kernel headers: $headers" >&2; exit 1; }
command -v curl >/dev/null && command -v patch >/dev/null && command -v make >/dev/null || { echo 'Need curl, patch, make and a C toolchain.' >&2; exit 1; }
work=$repo/build
archive=$work/linux-$version.tar.xz
src=$work/linux-$version
mkdir -p "$work"
if [[ ! -f $archive ]]; then curl -fL "https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-$version.tar.xz" -o "$archive.part"; mv "$archive.part" "$archive"; fi
printf '%s  %s\n' "$sha" "$archive" | sha256sum -c -
rm -rf "$src"
mkdir -p "$src"
tar -xJf "$archive" -C "$src" --strip-components=1 "linux-$version/drivers/gpu/drm/radeon"
patch -d "$src" -p1 < "$repo/patches/0001-imac10-1-hd4670-panel-and-encoder.patch"
patch -d "$src" -p1 < "$repo/patches/0002-standalone-module-build.patch"
make -C "$headers" M="$src/drivers/gpu/drm/radeon" modules
modinfo "$src/drivers/gpu/drm/radeon/radeon.ko"
echo "Built $src/drivers/gpu/drm/radeon/radeon.ko for $krel"
