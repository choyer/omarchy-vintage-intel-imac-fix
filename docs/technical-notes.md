# Technical notes

## Original failure

Limine and early firmware output were clear. When Linux Radeon modesetting took over, the internal panel changed to a four-way distorted image. DRM exposed the EDID-preferred 1920x1080 mode with 2080x1111 totals and a 138.5 MHz clock, while the VBIOS `LCD_Info` 1.2 table contained 1400x1050 at 108 MHz and flags `0x4d`.

The active scanout itself was coherent: one enabled CRTC, 1920x1080 ARGB8888, 1920-pixel pitch, zero offsets, no interlace, and no second scanout. DIG0 was the driver-selected path. Its live format register lacked RGB888 and FPDI, while the panel specification requires 8-bit two-port LVDS with FPDI mapping.

Changing the two live format bits after modeset affected the image but did not repair the spatial split. Applying the clock and format correction before the complete encoder/transmitter modeset produced a normal single console image. This is why the patch changes the driver's RAM copy of the ATOM table rather than writing a live register after startup.

## Encoder routing

Upstream Radeon code has an iMac10,1 workaround for an internal eDP panel. This 21.5-inch HD 4670 variant uses LVDS. With DisplayPort connected, the broad workaround caused:

```text
[drm:radeon_atom_pick_dig_encoder [radeon]] *ERROR* chosen encoder in use 0
```

Excluding only PCI identity `1002:9488` / `106b:00b6` from that workaround assigned the internal panel and external DisplayPort separate encoders. Both displays then operated at once during a test.

## Remaining GPU failure

The patch fixes panel programming and encoder selection, but accelerated desktop operation is not stable. Tests with DPM disabled and PCIe forced to Gen1 improved runtime, yet Radeon ring 0 eventually locked. Later boots reproduced the lock roughly 18 seconds after Hyprland started with only LVDS connected. Resets were followed by UVD failures, a lost OpenGL context, Hyprland abort/restart, TTM warnings, and another ring lock.

Border corruption was present in screenshots, so that artifact existed in rendered buffers rather than only in panel scanout. Solid opaque borders, disabled shadows/blur/animations, multiple Hyprland damage modes, Mesa flushes, and several R600 feature toggles did not resolve it. Running `grim` temporarily improved borders, which suggests an unresolved synchronization or cache problem.

These findings separate two issues:

1. The patch corrects the panel link and model-specific encoder routing.
2. A remaining RV730 command submission, synchronization, memory, or userspace rendering problem prevents claiming a stable accelerated Omarchy desktop.

## Known tested build

- Kernel: `7.2.5-3-omarchy`
- Upstream source: Linux 7.2.5
- Source archive SHA-256: `55ddf0df8325d9dad96fcff7bd93977d22e3f50af06527572af59b77c7632b78`
- Built module srcversion from the original investigation: `8164D8D20B481AC8C7896C9`
- Built module SHA-256 from the original investigation: `2de5980fb445d5984f4f940a218c3907d58d88a573412d9a06221fba385bbf68`

Those module hashes are provenance for the tested build, not portable expectations: compiler and kernel configuration changes can alter the resulting binary.
