#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
target=/
if [[ ${1:-} == --target-root ]]; then
  [[ -n ${2:-} ]] || { echo 'Usage: --target-root PATH' >&2; exit 2; }
  target=$(realpath "$2")
fi
TARGET_ROOT="$target" python3 - <<'PY'
from pathlib import Path
import os, re, shutil, time
root=Path(os.environ['TARGET_ROOT'])
menu=root/'boot/limine.conf'; text=menu.read_text()
names=('Omarchy iMac Radeon + Hyprland fix','Omarchy Radeon iMac Recovery Console')
for name in names:
    text=re.sub(rf'\n/{re.escape(name)}\n.*?(?=\n/|\Z)', '', text, flags=re.S)
stamp=time.strftime('%Y%m%d-%H%M%S'); backup=root/'boot/imac-video-test-backup'/f'limine-before-uninstall-vintage-imac-{stamp}.conf'
shutil.copy2(menu, backup); backup.chmod(0o600); menu.write_text(text.rstrip()+'\n')
Path(root/'boot/EFI/Linux/omarchy-imac-radeon-fix.efi').unlink(missing_ok=True)
print('Removed custom Limine entries and UKI; stock Omarchy entry preserved.')
print('Backup:', backup)
PY
echo 'Hyprland package was left installed. Restore stock Hyprland separately if required.'
