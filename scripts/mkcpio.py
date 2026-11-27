#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Write a reproducible newc cpio archive from a gen_init_cpio style spec.

Spec lines (same syntax as the kernel's usr/gen_init_cpio):
    dir   <name> <mode> <uid> <gid>
    file  <name> <source> <mode> <uid> <gid>
    slink <name> <target> <mode> <uid> <gid>
    nod   <name> <mode> <uid> <gid> <c|b> <major> <minor>

Device nodes need no root privileges. Every entry gets the same mtime
(--mtime, default $SOURCE_DATE_EPOCH), inode numbers count up from 1,
and entries are written in spec order.

Usage: mkcpio.py SPEC OUT [--mtime N]
"""

import argparse
import os
import stat
import sys

TYPES = {"dir": stat.S_IFDIR, "file": stat.S_IFREG,
         "slink": stat.S_IFLNK, "nod": None}


def entry(out, ino, name, mode, uid, gid, mtime, data=b"",
          nlink=1, rmaj=0, rmin=0):
    name_b = name.encode() + b"\0"
    hdr = "070701" + "".join(f"{v:08x}" for v in (
        ino, mode, uid, gid, nlink, mtime, len(data),
        0, 0, rmaj, rmin, len(name_b), 0))
    buf = hdr.encode() + name_b
    buf += b"\0" * (-len(buf) % 4)
    buf += data
    buf += b"\0" * (-len(buf) % 4)
    out.write(buf)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("spec")
    p.add_argument("out")
    p.add_argument("--mtime", type=int,
                   default=int(os.environ.get("SOURCE_DATE_EPOCH", "0")))
    a = p.parse_args()

    with open(a.spec) as f, open(a.out, "wb") as out:
        ino = 0
        for lineno, line in enumerate(f, 1):
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            w = line.split()
            kind = w[0]
            if kind not in TYPES:
                sys.exit(f"{a.spec}:{lineno}: unknown type {kind}")
            name = w[1].lstrip("/")
            ino += 1
            if kind == "dir":
                mode, uid, gid = int(w[2], 8), int(w[3]), int(w[4])
                entry(out, ino, name, stat.S_IFDIR | mode, uid, gid,
                      a.mtime, nlink=2)
            elif kind == "file":
                with open(w[2], "rb") as src:
                    data = src.read()
                mode, uid, gid = int(w[3], 8), int(w[4]), int(w[5])
                entry(out, ino, name, stat.S_IFREG | mode, uid, gid,
                      a.mtime, data)
            elif kind == "slink":
                mode, uid, gid = int(w[3], 8), int(w[4]), int(w[5])
                entry(out, ino, name, stat.S_IFLNK | mode, uid, gid,
                      a.mtime, w[2].encode())
            else:
                mode, uid, gid = int(w[2], 8), int(w[3]), int(w[4])
                ftype = {"c": stat.S_IFCHR, "b": stat.S_IFBLK}[w[5]]
                entry(out, ino, name, ftype | mode, uid, gid, a.mtime,
                      rmaj=int(w[6]), rmin=int(w[7]))
        entry(out, 0, "TRAILER!!!", 0, 0, 0, 0)


if __name__ == "__main__":
    main()
