# Linux Radeon panel fix for the 21.5-inch iMac10,1

Experimental Linux `radeon` driver corrections for this exact machine:

- Apple iMac10,1 (Late 2009, 21.5-inch)
- ATI Mobility Radeon HD 4670 (`1002:9488`)
- Apple subsystem `106b:00b6`
- LG Display LM215WF3-SLA1, 1920x1080 internal LVDS panel

The Apple VBIOS describes the internal panel as 1400x1050 at 108 MHz, RGB666/LDI. The physical panel and its EDID require 1920x1080 at 138.5 MHz with an 8-bit, two-port LVDS link. The patch corrects the driver's in-memory copy of the VBIOS LCD table and excludes this LVDS model from an existing model-wide iMac10,1 eDP encoder-routing quirk. It never writes the physical VBIOS.

## Current status

This is a test patch, not a production-ready desktop fix.

Verified on Omarchy kernel `7.2.5-3-omarchy`:

- Clear, correctly sized single-image Linux console on the internal panel.
- The four-way split caused by the bad panel data is corrected.
- Internal LVDS and external DisplayPort can be routed simultaneously without the earlier `chosen encoder in use 0` error.

Still failing:

- Hyprland/Mesa workloads can lock Radeon ring 0, lose the OpenGL context, and leave both screens black.
- Minor compositor border corruption and corrupted Chromium/Electron surfaces were observed before the lockups.
- UVD initialization is intermittent.
- DisplayPort hotplug has triggered a persistent graphical failure across warm reboots.

Treat the console target as the first and safest test. Keep SSH access available and do not make the patched graphical entry your default.

## What the patch changes

`patches/0001-imac10-1-hd4670-panel-and-encoder.patch` has strict runtime guards for the exact PCI device, Apple subsystem, native EDID mode, ATOM table revision, original clock, and original flags. It:

1. Changes the RAM copy of `LCD_Info` pixel clock from 108000 to 138500 kHz.
2. Enables RGB888 and FPDI while preserving the existing dual-link, dithering, and spread-spectrum flags.
3. Lets this HD 4670 LVDS variant use the normal DCE 3.2 encoder selection instead of the iMac10,1 eDP exception.

`patches/0002-standalone-module-build.patch` only allows the Radeon directory to build against installed kernel headers as an external module.

## Build on Omarchy/Arch

Install the matching headers and normal kernel build tools first. For Omarchy, the running kernel and its installed headers must match exactly.

```bash
./scripts/check-hardware.sh
./scripts/build.sh
```

The build script currently uses the official Linux 7.2.5 source archive and verifies its SHA-256 before compiling only `radeon.ko`. Set `KERNEL_RELEASE` only when building for another installed release whose headers are present. Porting the functional patch to another Linux source version requires review; changing `LINUX_VERSION` alone is not a compatibility guarantee.

## Install for a console test

Installation changes the module selected by the initramfs and rebuilds initramfs images. It preserves any prior module override for rollback and does not overwrite the package-owned kernel module.

```bash
sudo ./scripts/install.sh
```

Add these arguments to a separate bootloader test entry:

```text
radeon.dpm=0 radeon.pcie_gen2=0 systemd.unit=multi-user.target
```

Do not alter the normal/default entry. Reboot into the test entry with external displays disconnected. Confirm a stable 1920x1080 console before starting a display manager.

After boot, verify:

```bash
cat /proc/cmdline
lspci -nnk -s 02:00.0
journalctl -b -k | grep -Ei 'iMac LVDS|radeon|drm|ring|uvd|ttm|encoder'
```

Expected panel message:

```text
iMac LVDS: corrected panel clock to 138500 kHz and enabled RGB888/FPDI
```

Stop testing if the journal reports a Radeon ring lock, failed reset, TTM warning, or lost graphics context. Power off rather than repeatedly restarting the graphical session.

## Roll back

Boot a console or recovery entry, then run:

```bash
sudo ./scripts/uninstall.sh
```

This restores the previous override state, runs `depmod`, and rebuilds initramfs images. Remove the separate bootloader test entry manually afterward.

## Bootloader note

The tested Omarchy system uses Limine UKIs whose `path:` suffix is a 128-character BLAKE2b digest. A SHA-512 digest has the same length but is rejected. Recalculate an edited or newly generated UKI with:

```bash
b2sum /boot/EFI/Linux/your-test-image.efi
```

Bootloader layouts vary, so this repository intentionally does not automate Limine menu or UKI editing. Preserve a known-good recovery entry.

## Scope and evidence

The fix was developed from the machine's captured ATOM BIOS tables, DRM state, register reads, and the LM215WF3-SLA1 electrical interface specification. Captured ROMs, journals, EDIDs, crash reports, compiled modules, boot images, and machine-specific backups are deliberately excluded from this repository.

See [docs/technical-notes.md](docs/technical-notes.md) for the findings and remaining failure boundary.

## License

The patches and scripts are licensed under GPL-2.0-only. See [LICENSE](LICENSE).
