# 5. Reproduzierbarer Build

## 5.1 Ablauf

```sh
scripts/fetch-sources.sh toolchain   # alles laden und prüfen
scripts/build-kernel.sh              # zImage + DTB, initramfs eingebettet
scripts/build-bootimg.sh             # out/boot-htc-m7-stage1.img
# oder alles zusammen:
scripts/build.sh
```

Arbeitsverzeichnisse: `work/` (Quellen, Toolchain, Zwischenstände) und `out/`
(Ergebnisse). Beide stehen in `.gitignore`. `WORK=` und `OUT=` überschreiben sie.

| Schritt | Ergebnis | Am 2026-11-27 ausgeführt? |
|---|---|---|
| `fetch-sources.sh` | pmaports-Config, Kernelquelle, busybox | ✅ |
| `fetch-sources.sh toolchain` | Cross-GCC | Signatur und sha256 manuell geprüft ✅, Entpacken/Ausführen **nicht freigegeben** |
| `build-initramfs.sh` | `out/initramfs-stage1.cpio` sha256 `afd9c9b1…94fe7` | ✅, bitidentisch reproduziert |
| `build-kernel.sh` | `out/zImage-dtb` | ❌ (Toolchain) – Patch, Config-Merge und DTB-Bau ohne Cross-Compiler geprüft ✅ |
| `build-bootimg.sh` | `out/boot-htc-m7-stage1.img` | ❌ (braucht den Kernel) |

## 5.2 Was „reproduzierbar“ hier heißt

- Jede Eingabe ist in `sources.lock` über einen git-Commit oder eine
  Prüfsumme festgelegt. Die Skripte brechen bei Abweichungen ab.
- Alle Zeitstempel kommen aus `SOURCE_DATE_EPOCH` (Commitdatum des Kernels),
  Benutzer und Host sind fest (`KBUILD_BUILD_*`), `LC_ALL=C`, `TZ=UTC`.
- Der Kernel wird vor jedem Build auf `KERNEL_COMMIT` zurückgesetzt, die Patches
  werden mit `git am` angewendet. `LOCALVERSION=` verhindert das „+“ für einen
  ungetaggten Baum.
- Kein zufälliger Modul-Signaturschlüssel (der öffentliche Teil landet sonst in
  `vmlinux`), siehe Config-Fragment.
- initramfs: eigener newc-Writer (`scripts/mkcpio.py`) mit festen Rechten,
  Besitzern, Inodes und Zeitstempeln. Damit entstehen Geräteknoten ohne
  Root-Rechte, und das Ergebnis hängt nicht von der `umask` ab.
- Boot-Image: eigener v0-Packer (`scripts/bootimg.py`, Header wie AOSP
  mkbootimg v0, 1632 Bytes, SHA-1-ID). `bootimg.py info` zerlegt und prüft ein
  Image.

Ob der Kernel selbst bitidentisch reproduzierbar ist, kann ich erst nach dem
ersten Build durch zwei Builds in verschiedenen Verzeichnissen prüfen.

## 5.3 Vertrauenskette der Downloads

| Eingabe | Prüfung |
|---|---|
| pmaports | git-Commit `3156402c`; Config zusätzlich per sha512 aus dem APKBUILD |
| Kernel | git-Commit `9e451475` (shallow fetch per Hash) |
| Cross-GCC 15.2.0 (kernel.org crosstool) | `sha256sums.asc` mit GPG-Signatur „Kernel.org checksum autosigner“ `B8868C80…589DA6B1`, Schlüssel aus `git.kernel.org/…/pgpkeys.git`; dann sha256 |
| busybox-static 1.37.0-6+b9 (Debian 13, armhf) | `InRelease` mit VALIDSIG Debian Stable Release Key 13 `41587F7D…B2C39DE4` (Fingerprint auf ftp-master.debian.org/keys.html) → sha256 `Packages.xz` → sha256 `.deb` → sha256 Binary; Fallback snapshot.debian.org |

Warum nicht Alpine-busybox? Alpine baut busybox ohne `devmem`, `telnetd` und
`udhcpd` (beides nur im dynamischen `busybox-extras`). Geprüft in
`aports/main/busybox/busyboxconfig`.

## 5.4 Abhängigkeiten

Host (Ubuntu 24.04 getestet): `sh`, `git`, `curl`, `gpg`, `make`, `gcc`
(Host-Werkzeuge des Kernels), `bc`, `bison`, `flex`, `perl`, `python3` (≥ 3.8),
`openssl`/`libssl-dev`, `ar` (binutils), `tar`, `xz`, `gzip`, `cpio`,
`sha256sum`/`sha512sum`. Kein Root nötig.

Zielgerät: HTC One M7 mit entsperrtem Bootloader (htcdev). Zum Testen auf dem
Host: `fastboot` (Paket `android-tools-fastboot` / `fastboot`).

Unterschied zu pmaports: pmaports baut den Kernel mit clang/LLVM, diese
Skripte mit GCC 15.2. Die pmaports-Config wird per `olddefconfig` angepasst
(`CC_IS_GCC`). Der Build über pmbootstrap (`pmaports/patches/`) ist davon
unabhängig und nutzt weiter clang.

## 5.5 Nura/pmbootstrap (Stufe 4)

```sh
cd "$(pmbootstrap config aports)"
git am /pfad/zu/FalloutOS/pmaports/patches/*.patch
pmbootstrap init        # Gerät: htc-m7, UI: none
pmbootstrap build linux-postmarketos-qcom-apq8064 device-htc-m7
```

Nicht ausgeführt: pmbootstrap braucht sudo.
