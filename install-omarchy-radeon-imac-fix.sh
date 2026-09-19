#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
target=/
if [[ ${1:-} == --target-root ]]; then
  [[ -n ${2:-} ]] || { echo 'Usage: --target-root PATH' >&2; exit 2; }
  target=$(realpath "$2")
fi
[[ $EUID -eq 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
[[ -d "$target/etc" && -d "$target/boot" ]] || { echo "Invalid target root: $target" >&2; exit 1; }
[[ -f "$root/boot/omarchy-imac-radeon-fix.efi" ]] || {
  echo 'Missing boot/omarchy-imac-radeon-fix.efi; run tools/build-radeon-uki.sh first.' >&2; exit 1;
}
mkdir -p "$target/boot/EFI/Linux"
install -m 700 "$root/boot/omarchy-imac-radeon-fix.efi" "$target/boot/EFI/Linux/omarchy-imac-radeon-fix.efi"
src_sha=$(sha256sum "$root/boot/omarchy-imac-radeon-fix.efi" | awk '{print $1}')
dst_sha=$(sha256sum "$target/boot/EFI/Linux/omarchy-imac-radeon-fix.efi" | awk '{print $1}')
[[ "$src_sha" == "$dst_sha" ]] || { echo 'UKI copy verification failed.' >&2; exit 1; }
pkg=''
if [[ -f "$root/dist/hyprland-0.56.2-2.1-x86_64.pkg.tar.zst" ]]; then
  pkg="$root/dist/hyprland-0.56.2-2.1-x86_64.pkg.tar.zst"
elif [[ -f "$root/packages/hyprland-0.56.2-2.1-x86_64.pkg.tar.zst" ]]; then
  pkg="$root/packages/hyprland-0.56.2-2.1-x86_64.pkg.tar.zst"
else
  echo 'Hyprland package not found; install it separately or run tools/build-hyprland-package.sh.' >&2
  exit 1
fi
if [[ "$target" == / ]]; then
  pacman -U --needed "$pkg"
else
  command -v arch-chroot >/dev/null || { echo 'arch-chroot is required for --target-root mode.' >&2; exit 1; }
  target_pkg="$target/tmp/hyprland-imac-fix.pkg.tar.zst"
  install -m 600 "$pkg" "$target_pkg"
  arch-chroot "$target" pacman -U --needed --noconfirm /tmp/hyprland-imac-fix.pkg.tar.zst
  rm -f "$target_pkg"
fi
python3 "$root/tools/write-limine-entry.py" --root "$target"
echo 'Installed. No reboot was performed.'
