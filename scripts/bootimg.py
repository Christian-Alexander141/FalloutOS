#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Create and inspect Android boot images, header version 0.

HTC hboot on the One M7 boots version-0 images (the format AOSP mkbootimg
writes by default for header_version 0). Layout, page aligned:

    header | kernel | ramdisk | second

The header id field is SHA-1 over each section followed by its size as a
little-endian u32, the same as AOSP mkbootimg for version 0.

Usage:
    bootimg.py pack --kernel zImage-dtb --ramdisk initrd.gz --out boot.img \
        --base 0x80600000 --kernel-offset 0x8000 --ramdisk-offset 0x4000000 \
        --second-offset 0xf00000 --tags-offset 0x100 --pagesize 2048 \
        --cmdline "..."
    bootimg.py info boot.img
"""

import argparse
import hashlib
import struct
import sys

MAGIC = b"ANDROID!"
# magic, kernel size/addr, ramdisk size/addr, second size/addr, tags addr,
# page size, header version, os version, name[16], cmdline[512], id[8 x u32],
# extra cmdline[1024]
HEADER = struct.Struct("<8s10I16s512s32s1024s")
CMDLINE_MAX = 512 + 1024 - 1  # both fields NUL terminated together


def pad(data, pagesize):
    rem = len(data) % pagesize
    return data if rem == 0 else data + b"\0" * (pagesize - rem)


def image_id(sections):
    sha = hashlib.sha1()
    for data in sections:
        sha.update(data)
        sha.update(struct.pack("<I", len(data)))
    return sha.digest().ljust(32, b"\0")


def pack(args):
    with open(args.kernel, "rb") as f:
        kernel = f.read()
    ramdisk = b""
    if args.ramdisk:
        with open(args.ramdisk, "rb") as f:
            ramdisk = f.read()
    second = b""

    cmdline = args.cmdline.encode()
    if len(cmdline) > CMDLINE_MAX:
        sys.exit(f"cmdline too long ({len(cmdline)} > {CMDLINE_MAX})")
    name = args.name.encode()
    if len(name) > 15:
        sys.exit("name too long (max 15 bytes)")

    header = HEADER.pack(
        MAGIC,
        len(kernel), args.base + args.kernel_offset,
        len(ramdisk), args.base + args.ramdisk_offset,
        len(second), args.base + args.second_offset,
        args.base + args.tags_offset,
        args.pagesize,
        0,  # header version
        0,  # os version
        name.ljust(16, b"\0"),
        cmdline[:511].ljust(512, b"\0"),
        image_id([kernel, ramdisk, second]),
        cmdline[511:].ljust(1024, b"\0"),
    )

    out = pad(header, args.pagesize) + pad(kernel, args.pagesize)
    out += pad(ramdisk, args.pagesize) + pad(second, args.pagesize)
    if args.max_size and len(out) > args.max_size:
        sys.exit(f"image is {len(out)} bytes, partition holds {args.max_size}")
    with open(args.out, "wb") as f:
        f.write(out)
    print(f"{args.out}: {len(out)} bytes")


def info(args):
    with open(args.image, "rb") as f:
        data = f.read()
    if data[:8] != MAGIC:
        sys.exit("not an Android boot image")
    (_, ksize, kaddr, rsize, raddr, ssize, saddr, taddr, pagesize, hver,
     _osver, name, cmd, img_id, extra) = HEADER.unpack_from(data)
    off = pagesize
    sections = []
    for size in (ksize, rsize, ssize):
        sections.append(data[off:off + size])
        off += (size + pagesize - 1) // pagesize * pagesize
    ok = image_id(sections) == img_id
    cmdline = (cmd.rstrip(b"\0") + extra.rstrip(b"\0")).decode(errors="replace")
    print(f"header_version {hver}")
    print(f"page_size      {pagesize}")
    print(f"kernel         {ksize:>9} bytes @ 0x{kaddr:08x}")
    print(f"ramdisk        {rsize:>9} bytes @ 0x{raddr:08x}")
    print(f"second         {ssize:>9} bytes @ 0x{saddr:08x}")
    print(f"tags                           @ 0x{taddr:08x}")
    print(f"name           {name.rstrip(bytes(1)).decode(errors='replace')!r}")
    print(f"cmdline        {cmdline!r}")
    print(f"id             {img_id[:20].hex()} ({'ok' if ok else 'MISMATCH'})")
    print(f"total          {len(data)} bytes")
    if not ok:
        sys.exit(1)


def main():
    num = lambda s: int(s, 0)
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = p.add_subparsers(dest="cmd", required=True)

    pk = sub.add_parser("pack")
    pk.add_argument("--kernel", required=True)
    pk.add_argument("--ramdisk")
    pk.add_argument("--out", required=True)
    pk.add_argument("--cmdline", default="")
    pk.add_argument("--name", default="")
    pk.add_argument("--base", type=num, required=True)
    pk.add_argument("--kernel-offset", type=num, required=True)
    pk.add_argument("--ramdisk-offset", type=num, required=True)
    pk.add_argument("--second-offset", type=num, required=True)
    pk.add_argument("--tags-offset", type=num, required=True)
    pk.add_argument("--pagesize", type=num, required=True)
    pk.add_argument("--max-size", type=num, default=0,
                    help="fail if the image exceeds this many bytes")
    pk.set_defaults(func=pack)

    inf = sub.add_parser("info")
    inf.add_argument("image")
    inf.set_defaults(func=info)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
