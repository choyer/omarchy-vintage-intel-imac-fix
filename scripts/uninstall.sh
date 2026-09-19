#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
krel=${KERNEL_RELEASE:-$(uname -r)}
target=/usr/lib/modules/$krel/updates/radeon.ko.zst
state=/var/lib/imac-radeon-panel-fix/$krel
[[ -e $state/installed ]] || { echo "No recorded installation for $krel" >&2; exit 1; }
if [[ -f $state/radeon.ko.zst.previous ]]; then cp -a "$state/radeon.ko.zst.previous" "$target"; else rm -f "$target"; fi
depmod "$krel"
mkinitcpio -P
rm -f "$state/installed"
echo 'Restored the previous Radeon override state and rebuilt initramfs images.'
