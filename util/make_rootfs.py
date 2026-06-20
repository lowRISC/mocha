#!/usr/bin/env python
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Mocha root filesystem generator script.

import argparse
import contextlib
import gzip
import os
import shutil
import struct
import subprocess
import zlib
from pathlib import Path


def run(args) -> None:
    # Root of the filesystem - "/" - is at workdir/fs_root.
    workdir = Path(args.workdir)
    fs_root = workdir / Path("fs_root")

    with contextlib.suppress(FileExistsError):
        Path.mkdir(fs_root, parents=False)

    if args.include_tree:
        shutil.copytree(Path(args.include_tree), fs_root, dirs_exist_ok=True)

    fs_root_bin = fs_root / Path("bin")
    with contextlib.suppress(FileExistsError):
        Path.mkdir(fs_root_bin, parents=True)

    fs_busybox_path = fs_root_bin / Path("busybox")
    with contextlib.suppress(FileExistsError):
        fs_busybox_path.hardlink_to(args.busybox)

    compressed_rootfs = make_cpio_archive(workdir, fs_root)
    make_uboot_image(compressed_rootfs)


def make_cpio_archive(workdir: Path, fs_root: Path) -> Path:
    """
    Make a Gzip-compressed CPIO archive of the filesystem tree at 'fs_root'.
    Returns the path of the generated archive, which will be placed in 'workdir'.
    """
    files = []
    # Collect all file paths in the tree rooted at fs_root, relative to that root.
    for directory, ds, fs in os.walk(fs_root):
        files.extend([(Path(directory) / Path(file)).relative_to(fs_root) for file in ds + fs])

    files = "\n".join(str(file) for file in files).encode()
    res = subprocess.run(
        ["cpio", "-o", "-H", "newc"],
        cwd=fs_root,
        input=files,
        capture_output=True,
        check=True,
    )

    # Compress and write.
    compressed_rootfs = workdir / Path("rootfs.cpio.gz")
    with Path.open(compressed_rootfs, "wb") as f:
        f.write(gzip.compress(res.stdout))

    return compressed_rootfs


def uboot_image_header(name: str, header_crc: int, data_size: int, data_crc: int) -> bytes:
    """
    Generate a U-Boot legacy uImage header for a Gzip-compressed Linux ramdisk (initramfs).
    This header contains the it's own CRC field, which is computed with this field set to 0,
    therefore to generate a valid header we need to call this once with the header CRC as 0 to
    compute the value for the field.
    """
    MAGIC = 0x27051956
    OS_LINUX = 5
    ARCH_RISCV = 26
    TYPE_RAMDISK = 3
    COMP_GZIP = 1
    name_bytes = name.encode("ascii")[:32].ljust(32, b"\0")
    return struct.pack(
        ">I I I I I I I B B B B 32s",
        MAGIC,  # Magic number.
        header_crc,  # CRC32 of this header, computed with this set to 0.
        0,  # Timestamp.
        data_size,  # Data size.
        0,  # Image load address.
        0,  # Image entrypoint address.
        data_crc,  # CRC32 of the image payload data.
        OS_LINUX,  # Operating system.
        ARCH_RISCV,  # Architecture.
        TYPE_RAMDISK,  # Image type.
        COMP_GZIP,  # Compression type.
        name_bytes,  # Image name.
    )


def make_uboot_image(image: Path) -> Path:
    """
    Generate a U-Boot legacy uImage wrapping the root filesystem archive.
    """
    NAME = "Mocha initramfs root filesystem"
    filename = Path(image)
    for _ in range(len(image.suffixes)):
        filename = filename.with_name(filename.stem)
    filename = filename.with_name(filename.name + "_uboot_image")

    with Path.open(image, "rb") as f:
        data = f.read()
        data_size = len(data)
        data_crc = zlib.crc32(data)

        # Use 0 as the header CRC, so that we can calculate it.
        header = uboot_image_header(NAME, 0, data_size, data_crc)
        header_crc = zlib.crc32(header)
        # Use the actual header CRC.
        header = uboot_image_header(NAME, header_crc, data_size, data_crc)

        with Path.open(filename, "wb") as out:
            out.write(header + data)
            return filename


def main() -> None:
    parser = argparse.ArgumentParser(description="Mocha initramfs filesystem generator.")
    parser.add_argument("workdir", type=Path, help="Temporary work directory.")
    parser.add_argument("--include-tree", type=Path, help="Path to file tree to include.")
    parser.add_argument("--busybox", type=Path, required=True, help="Path to busybox binary.")

    args = parser.parse_args()
    run(args)


if __name__ == "__main__":
    main()
