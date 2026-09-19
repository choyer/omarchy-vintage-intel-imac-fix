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
terminal if the internal panel is distorted. The following procedure assumes
you are at a root shell in the Omarchy ISO.

First identify the installed system's partitions. Do not guess from the device
name; compare the sizes, filesystem types, and labels:

```sh
lsblk -e7 -o NAME,SIZE,FSTYPE,FSVER,LABEL,UUID,MOUNTPOINTS
blkid
```

The EFI System Partition is normally a small `vfat` partition. The root
partition is usually the large `btrfs` partition on an Omarchy installation.
Set shell variables to the partitions you identified:

```sh
ROOT_DEV=/dev/<root-partition>
EFI_DEV=/dev/<efi-partition>
```

Create the target mount point and mount the root filesystem:

```sh
sudo mkdir -p /mnt
sudo mount "$ROOT_DEV" /mnt
```

If the root filesystem is Btrfs and the first mount does not contain `etc`,
inspect its subvolumes and remount the installed root subvolume:

```sh
sudo btrfs subvolume list /mnt
sudo umount /mnt
sudo mount -o subvol=@ "$ROOT_DEV" /mnt
```

Use the subvolume name shown by the listing if it is not `@`. Verify that this
is the installed system before continuing:

```sh
test -f /mnt/etc/os-release && cat /mnt/etc/os-release
test -d /mnt/boot
```

Mount the EFI System Partition at the target's `/boot` directory:

```sh
sudo mount "$EFI_DEV" /mnt/boot
```

Confirm that the Limine configuration and EFI loaders are present:

```sh
findmnt /mnt
findmnt /mnt/boot
ls -l /mnt/boot/limine.conf
ls -l /mnt/boot/EFI/Linux
```

If `/mnt/boot/limine.conf` is missing, stop and check the partition choices;
the EFI partition is either not mounted or this is not the installed root.

Locate the USB bundle, then run the installer from it:

```sh
lsblk -e7 -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS
sudo mkdir -p /run/media/omarchy-fix
sudo mount /dev/<usb-partition> /run/media/omarchy-fix
cd /run/media/omarchy-fix/omarchy-vintage-intel-imac-fix
sudo ./install-omarchy-radeon-imac-fix.sh --target-root /mnt
```

The installer installs Hyprland inside `/mnt`, copies the UKI to the target
EFI partition, calculates its final BLAKE2b hash, and updates only the target
Limine configuration. It does not start Hyprland or reboot.

Before rebooting, verify the new entry and UKI:

```sh
sudo grep -A6 -F '/Omarchy iMac Radeon + Hyprland fix' /mnt/boot/limine.conf
sudo ls -lh /mnt/boot/EFI/Linux/omarchy-imac-radeon-fix.efi
```

Unmount cleanly and reboot:

```sh
sudo umount -R /mnt
sudo reboot
```

At Limine, select `Omarchy iMac Radeon + Hyprland fix`. The original
`+Omarchy` entry remains available as the fallback.

After building or copying the UKI and Hyprland package into this directory,
create a release archive with:

```sh
./tools/prepare-release.sh 1.0.0
```
