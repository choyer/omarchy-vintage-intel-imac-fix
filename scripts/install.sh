#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
"$repo/scripts/check-hardware.sh"
krel=${KERNEL_RELEASE:-$(uname -r)}
module=$repo/build/linux-${LINUX_VERSION:-7.2.5}/drivers/gpu/drm/radeon/radeon.ko
target=/usr/lib/modules/$krel/updates/radeon.ko.zst
state=/var/lib/imac-radeon-panel-fix/$krel
[[ -f $module ]] || { echo 'Build the module first with scripts/build.sh' >&2; exit 1; }
[[ $(modinfo -F vermagic "$module") == "$krel "* ]] || { echo 'Module vermagic does not match running kernel.' >&2; exit 1; }
[[ ! -e $state/installed ]] || { echo "Already installed for $krel" >&2; exit 1; }
mkdir -p "$state"
if [[ -e $target ]]; then cp -a "$target" "$state/radeon.ko.zst.previous"; else : > "$state/no-previous-override"; fi
zstd -q -f "$module" -o "$target"
depmod "$krel"
mkinitcpio -P
printf '%s\n' "$(sha256sum "$module")" > "$state/installed"
echo 'Installed the guarded Radeon override and rebuilt initramfs images.'
echo 'For initial testing add: radeon.dpm=0 radeon.pcie_gen2=0 systemd.unit=multi-user.target'
echo 'Do not start a graphical session until the console is confirmed stable.'
