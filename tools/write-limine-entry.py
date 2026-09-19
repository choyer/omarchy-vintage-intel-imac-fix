#!/usr/bin/env python3
from pathlib import Path
import hashlib, os, re, shutil, time
import argparse

GRAPHICAL = 'Omarchy iMac Radeon + Hyprland fix'
RECOVERY = 'Omarchy Radeon iMac Recovery Console'
OLD_RECOVERY = 'iMac Radeon corrected panel encoder PCIe Gen1 test'
ARGS = ('radeon.dpm=0', 'radeon.pcie_gen2=0', 'radeon.uvd=0')

def get(text, name):
    m = re.search(rf'^/{re.escape(name)}\n(.*?)(?=^/|\Z)', text, re.M | re.S)
    return m.group(1) if m else None

def require(ok, msg):
    if not ok: raise RuntimeError(msg)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, default=Path('/'))
    root = parser.parse_args().root.resolve()
    menu = root / 'boot/limine.conf'
    uki = root / 'boot/EFI/Linux/omarchy-imac-radeon-fix.efi'
    require(os.geteuid() == 0, 'Run with sudo')
    require(menu.is_file() and uki.is_file(), 'Missing target Limine config or patched UKI')
    before = menu.read_text()
    require(get(before, GRAPHICAL) is None, 'Graphical fix entry already exists')
    normal = get(before, '+Omarchy')
    require(normal is not None, 'Stock +Omarchy entry is missing')
    path = re.search(r'^  path: .+$', normal, re.M)
    cmd = re.search(r'^  cmdline: (.*)$', normal, re.M)
    require(path and cmd, 'Stock entry lacks path or cmdline')
    args = cmd.group(1).split()
    require('nomodeset' not in args, 'Stock entry unexpectedly uses nomodeset')
    for arg in ARGS:
        if arg not in args: args.append(arg)
    digest = hashlib.blake2b(uki.read_bytes()).hexdigest()
    body = re.sub(r'^  path: .+$', f'  path: boot():/EFI/Linux/{uki.name}#{digest}', normal, count=1, flags=re.M)
    body = re.sub(r'^  cmdline: .+$', '  cmdline: ' + ' '.join(args), body, count=1, flags=re.M)
    after = before.rstrip() + f'\n\n/{GRAPHICAL}\n' + body.rstrip() + '\n'

    old = get(after, OLD_RECOVERY)
    if old is not None:
        after = re.sub(rf'^/{re.escape(OLD_RECOVERY)}\n', f'/{RECOVERY}\n', after, count=1, flags=re.M)
    recovery = get(after, RECOVERY)
    if recovery is not None:
        recovery = re.sub(r'^  path: .+$', f'  path: boot():/EFI/Linux/{uki.name}#{digest}', recovery, count=1, flags=re.M)
        recovery_cmd = re.search(r'^  cmdline: (.*)$', recovery, re.M)
        require(recovery_cmd is not None, 'Recovery entry lacks cmdline')
        recovery_args = recovery_cmd.group(1).split()
        for arg in ARGS:
            if arg not in recovery_args: recovery_args.append(arg)
        recovery = re.sub(r'^  cmdline: .+$', '  cmdline: ' + ' '.join(recovery_args), recovery, count=1, flags=re.M)
        after = re.sub(rf'^/{re.escape(RECOVERY)}\n.*?(?=^/|\Z)', f'/{RECOVERY}\n{recovery.rstrip()}\n', after, count=1, flags=re.M | re.S)
    else:
        recovery = re.sub(r'^  path: .+$', f'  path: boot():/EFI/Linux/{uki.name}#{digest}', body, count=1, flags=re.M)
        recovery_args = args + ['systemd.unit=multi-user.target']
        recovery = re.sub(r'^  cmdline: .+$', '  cmdline: ' + ' '.join(recovery_args), recovery, count=1, flags=re.M)
        after = after.rstrip() + f'\n\n/{RECOVERY}\n' + recovery.rstrip() + '\n'
    stamp = time.strftime('%Y%m%d-%H%M%S')
    backup = root / 'boot/imac-video-test-backup' / f'limine-before-omarchy-vintage-imac-{stamp}.conf'
    backup.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(menu, backup); backup.chmod(0o600)
    menu.write_text(after); os.sync()
    require(menu.read_text() == after, 'Limine verification failed')
    print('Created:', GRAPHICAL)
    print('Recovery entry:', RECOVERY)
    print('UKI BLAKE2b:', digest)
    print('Backup:', backup)

if __name__ == '__main__': main()
