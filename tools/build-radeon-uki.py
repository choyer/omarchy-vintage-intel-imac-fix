#!/usr/bin/env python3
"""Build the patched Radeon module into a copy of an Omarchy UKI.

The output is deliberately not installed. The installer copies it to /boot,
hashes the final file, and writes the Limine entry.
"""
from argparse import ArgumentParser
from pathlib import Path
import hashlib, os, shutil, struct, subprocess, tempfile

def run(*args, cwd=None, capture=False):
    return subprocess.run(args, cwd=cwd, check=True, text=True,
                          capture_output=capture).stdout.strip() if capture else None

def require(ok, message):
    if not ok:
        raise RuntimeError(message)

def section(image, name, output):
    run("objcopy", f"--dump-section", f"{name}={output}", str(image))

def normalize_pe(image, payloads):
    data = bytearray(image.read_bytes())
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    require(data[pe:pe+4] == b"PE\0\0", "Invalid PE/COFF UKI")
    count = struct.unpack_from("<H", data, pe + 6)[0]
    opt_size = struct.unpack_from("<H", data, pe + 20)[0]
    opt = pe + 24
    sec_align, file_align = struct.unpack_from("<II", data, opt + 32)
    ranges, seen = [], set()
    for i in range(count):
        h = opt + opt_size + i * 40
        name = data[h:h+8].rstrip(b"\0").decode()
        vsize, rva, raw_size, raw_off = struct.unpack_from("<IIII", data, h + 8)
        if name in payloads:
            payload = payloads[name]
            expected = (len(payload) + file_align - 1) // file_align * file_align
            require(raw_size == expected, f"Unexpected {name} raw section size")
            require(data[raw_off:raw_off+len(payload)] == payload,
                    f"{name} payload verification failed")
            require(not any(data[raw_off+len(payload):raw_off+raw_size]),
                    f"{name} padding is not zero")
            struct.pack_into("<I", data, h + 8, len(payload))
            seen.add(name)
            vsize = len(payload)
        ranges.append((rva, rva + max(vsize, raw_size), name))
    require(seen == set(payloads), "Missing updated UKI section")
    for a, b in zip(sorted(ranges), sorted(ranges)[1:]):
        require(a[1] <= b[0], f"PE sections overlap: {a[2]} / {b[2]}")
    end = max(x[1] for x in ranges)
    struct.pack_into("<I", data, opt + 56,
                     (end + sec_align - 1) // sec_align * sec_align)
    struct.pack_into("<I", data, opt + 64, 0)
    image.write_bytes(data)

def main():
    p = ArgumentParser()
    p.add_argument("--root", type=Path, required=True)
    p.add_argument("--kernel", required=True)
    p.add_argument("--kernel-source", type=Path)
    p.add_argument("--base-uki", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()
    require(os.geteuid() == 0, "Run this tool with sudo")
    build = Path("/usr/lib/modules") / a.kernel / "build"
    require(build.is_dir(), f"Missing kernel build tree: {build}")
    require(a.base_uki.is_file(), f"Missing base UKI: {a.base_uki}")
    patch = a.root / "patches/panel-encoder-combined.patch"
    source_tree = a.kernel_source or (a.root / "work" / ("linux-" + a.kernel.split("-", 1)[0]))
    if not (source_tree / "drivers/gpu/drm/radeon/radeon_connectors.c").is_file():
        source_tree = build
    radeon = source_tree / "drivers/gpu/drm/radeon"
    require(radeon.is_dir(), "Kernel build tree has no Radeon source directory")
    require((radeon / "radeon_connectors.c").is_file(),
            "Radeon C sources are required; pass --kernel-source pointing to the matching Omarchy kernel source")

    with tempfile.TemporaryDirectory(prefix="omarchy-imac-radeon-") as td:
        temp = Path(td)
        source = temp / "drivers/gpu/drm/radeon"
        shutil.copytree(radeon, source, symlinks=True)
        run("patch", "-p1", "-i", str(patch), cwd=temp)
        run("make", "-C", str(build), f"M={source}", "modules")
        module = source / "radeon.ko"
        require(module.is_file(), "Radeon module build produced no radeon.ko")
        srcversion = run("modinfo", "-F", "srcversion", str(module), capture=True)

        modroot = temp / "modroot"
        (modroot / "lib").symlink_to("usr/lib")
        modules = modroot / "usr/lib/modules" / a.kernel
        shutil.copytree(Path("/usr/lib/modules") / a.kernel, modules,
                        symlinks=True, ignore=shutil.ignore_patterns("build", "source", "updates"))
        candidates = list((modules / "kernel/drivers/gpu/drm/radeon").glob("radeon.ko*"))
        require(len(candidates) == 1, "Could not identify stock Radeon module")
        compressed = subprocess.check_output(["zstd", "-q", "-c", str(module)])
        candidates[0].write_bytes(compressed)
        run("depmod", "-b", str(modroot), a.kernel)
        initrd = temp / "initrd"
        run("mkinitcpio", "--kernel", a.kernel, "--moduleroot", str(modroot),
            "--generate", str(initrd), "--nopost")

        old_cmdline = temp / "old-cmdline"
        section(a.base_uki, ".cmdline", old_cmdline)
        args = old_cmdline.read_bytes().rstrip(b"\0\n").decode().split()
        for arg in ("radeon.dpm=0", "radeon.pcie_gen2=0", "radeon.uvd=0"):
            if arg not in args:
                args.append(arg)
        cmdline = temp / "cmdline"
        cmdline.write_bytes((" ".join(args)).encode() + b"\0")
        image = temp / "image.efi"
        run("objcopy", "--update-section", f".initrd={initrd}",
            "--update-section", f".cmdline={cmdline}", str(a.base_uki), str(image))
        normalize_pe(image, {".initrd": initrd.read_bytes(), ".cmdline": cmdline.read_bytes()})
        a.output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(image, a.output)
        print(f"Built {a.output}")
        print(f"Kernel: {a.kernel}")
        print(f"Radeon srcversion: {srcversion}")
        print(f"BLAKE2b: {hashlib.blake2b(a.output.read_bytes()).hexdigest()}")
        print("Arguments:", " ".join(args))

if __name__ == "__main__":
    main()
