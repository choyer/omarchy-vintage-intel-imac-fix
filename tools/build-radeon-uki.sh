#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
kver=${1:-$(uname -r)}
base_uki=${2:-/boot/EFI/Linux/omarchy_linux-omarchy.efi}
out=${3:-$root/boot/omarchy-imac-radeon-fix.efi}
source_tree=${KERNEL_SOURCE:-$root/work/linux-${kver%%-*}}
[[ $EUID -eq 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
python3 "$root/tools/build-radeon-uki.py" --root "$root" --kernel "$kver" --kernel-source "$source_tree" --base-uki "$base_uki" --output "$out"
