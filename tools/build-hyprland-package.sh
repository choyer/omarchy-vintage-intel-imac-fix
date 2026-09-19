#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=${HYPRLAND_WORKDIR:-$root/work/hyprland-0.56.2}
src="$work/source"
build="$work/build"
jobs=${JOBS:-2}

mkdir -p "$work"
if [[ ! -d "$src/.git" ]]; then
  git clone --recursive --branch v0.56.2 https://github.com/hyprwm/Hyprland.git "$src"
else
  git -C "$src" submodule update --init --recursive
fi
git -C "$src" checkout --detach efb50993780079460b0cbed1363e2166a2de1d9f
if ! git -C "$src" diff --quiet -- src/render/shaders/glsl/border.glsl; then
  :
else
  git -C "$src" apply "$root/hyprland/border-alpha.patch"
fi

cmake -G Ninja -S "$src" -B "$build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_INSTALL_LIBDIR=/usr/lib \
  -DCMAKE_INSTALL_LIBEXECDIR=libexec \
  -DBUILD_TESTING=OFF
cmake --build "$build" --parallel "$jobs"

out="$root/dist"
mkdir -p "$out"
cp "$root/hyprland/PKGBUILD" "$out/PKGBUILD"
HYPRLAND_BUILD_DIR="$build" HYPRLAND_SOURCE_DIR="$src" \
  makepkg --syncdeps --needed --noconfirm --force -p "$out/PKGBUILD"
echo "Created Hyprland package in $out"
