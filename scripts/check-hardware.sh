#!/usr/bin/env bash
set -euo pipefail
[[ $(cat /sys/class/dmi/id/product_name) == iMac10,1 ]] || { echo 'Unsupported DMI product; expected iMac10,1' >&2; exit 1; }
dev=/sys/bus/pci/devices/0000:02:00.0
[[ -r $dev/vendor && -r $dev/device && -r $dev/subsystem_vendor && -r $dev/subsystem_device ]] || { echo 'Expected GPU at 0000:02:00.0 was not found' >&2; exit 1; }
actual=$(cat "$dev/vendor" "$dev/device" "$dev/subsystem_vendor" "$dev/subsystem_device" | sed 's/0x//g' | paste -sd: -)
[[ $actual == 1002:9488:106b:00b6 ]] || { echo "Unsupported GPU identity: $actual" >&2; exit 1; }
echo 'Matched iMac10,1 with Radeon HD 4670, Apple subsystem 106b:00b6.'
