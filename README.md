# omarchy-vintage-intel-imac-fix

This release combines the working Radeon panel fix for the Late 2009 iMac10,1
with the Hyprland 0.56.2 border shader fix that removes the llvmpipe border
artifacts.

The installer creates one graphical Limine entry named `Omarchy iMac Radeon +
Hyprland fix`. It leaves the stock `+Omarchy` entry available and renames the
old console recovery entry to `Omarchy Radeon iMac Recovery Console`.

The supplied UKI is tied to the Omarchy kernel version recorded in its manifest.
When the kernel changes, obtain the matching Omarchy kernel source and rebuild
it with `tools/build-radeon-uki.sh` before installing. The installed kernel
headers alone are not enough: Arch header packages do not contain the Radeon C
sources that must receive the patch. Hyprland can be rebuilt with
`tools/build-hyprland-package.sh`.

The scripts never make a reboot decision and preserve timestamped Limine
backups.

## Installing from the Omarchy ISO

Install stock Omarchy with the external display/KVM attached, or use a text
terminal if the internal panel is distorted. Mount the installed system at
`/mnt`, make sure its EFI partition is mounted at `/mnt/boot`, then run this
bundle from the USB drive:

```sh
sudo ./install-omarchy-radeon-imac-fix.sh --target-root /mnt
```

Target-root mode installs the Hyprland package inside `/mnt`, copies the UKI to
the target EFI partition, calculates its final BLAKE2b hash, and updates only
the target Limine configuration. It does not start Hyprland or reboot. The ISO
must provide `arch-chroot`, and the target must already have normal Omarchy
dependencies installed.

After building or copying the UKI and Hyprland package into this directory,
create a release archive with:

```sh
./tools/prepare-release.sh 1.0.0
```
