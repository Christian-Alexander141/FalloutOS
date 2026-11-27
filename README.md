# FalloutOS

[English](#english) · [Deutsch](#deutsch)

---

## English

FalloutOS is a minimal, shell-based operating system for older smartphones,
based on postmarketOS (renamed **Nura** in September 2026). No X11, no
Wayland, no window manager: boot loader → Linux kernel → display → Linux TTY →
shell.

### First device: HTC One M7 (`htc-m7`)

The existing postmarketOS port (vendor kernel 3.4.10) is archived and never
got the display working without Android userspace. FalloutOS moves the M7 to
the mainline **Linux 7.2** kernel (`apq8064-mainline` fork, already used by
Nura for the Nexus 7 2013 and Galaxy S4) with a new device tree.

| Milestone | Goal | Status |
|---|---|---|
| 1a | Kernel boots, shell over USB, read missing hardware data | prepared, kernel not compiled yet |
| 1b | TTY on the display (`simple-framebuffer`) | waiting for 1a data |
| 1c | Own DRM panel driver and backlight | planned |
| 2 | Touchscreen + on-screen keyboard | planned |
| 3 | WLAN (BCM4335 via `brcmfmac`) | planned |

**Nothing has been tested on hardware yet.** Built and verified so far: the
device tree (compiles without own warnings), kernel config, a bit-for-bit
reproducible initramfs, the boot image packer and the pmaports patches (apply
cleanly). The kernel itself still needs the cross compiler, which is
downloaded and signature-checked but not yet unpacked and run.

### Layout

| Path | Content |
|---|---|
| `docs/htc-m7/` | inventory, failure analysis, hardware, kernel strategy, build, test plan (German) |
| `kernel/patches/` | device tree patch against `apq8064-mainline/linux@9e451475` |
| `kernel/config/` | config fragment on top of the pmaports kernel config |
| `pmaports/patches/` | patches for Nura pmaports (kernel package fix, mainline `device-htc-m7`) |
| `initramfs/` | stage-1 `/init` and read-only hardware probe |
| `scripts/` | fetch/verify and build scripts, boot image and cpio writers |
| `sources.lock` | every pinned input with commit hash or checksum |

### Build

```sh
scripts/build.sh    # fetch + verify, kernel with built-in initramfs, boot.img
```

Results go to `out/`, sources and toolchain to `work/` (both ignored by git).
No root needed. Details: [docs/htc-m7/05-build.md](docs/htc-m7/05-build.md).

Test on the phone in RAM only, without writing anything:
`fastboot boot out/boot-htc-m7-stage1.img`. See
[docs/htc-m7/06-testplan.md](docs/htc-m7/06-testplan.md) before flashing.

---

## Deutsch

FalloutOS ist ein minimales, shell-basiertes Betriebssystem für ältere
Smartphones auf Basis von postmarketOS (seit September 2026 **Nura**). Kein
X11, kein Wayland, kein Window Manager: Bootloader → Linux-Kernel → Display →
Linux-TTY → Shell.

### Erstes Gerät: HTC One M7 (`htc-m7`)

Der bisherige postmarketOS-Port (Vendor-Kernel 3.4.10) ist archiviert und hat
das Display ohne Android-Userspace nie zum Laufen gebracht. FalloutOS stellt das
M7 auf den Mainline-Kernel **Linux 7.2** um (`apq8064-mainline`-Fork, den Nura
bereits für Nexus 7 2013 und Galaxy S4 nutzt), mit einem neuen Device Tree.

| Meilenstein | Ziel | Status |
|---|---|---|
| 1a | Kernel bootet, Shell über USB, fehlende Hardwaredaten auslesen | vorbereitet, Kernel noch nicht kompiliert |
| 1b | TTY auf dem Display (`simple-framebuffer`) | wartet auf Daten aus 1a |
| 1c | Eigener DRM-Panel-Treiber und Hintergrundbeleuchtung | geplant |
| 2 | Touchscreen + Bildschirmtastatur | geplant |
| 3 | WLAN (BCM4335 über `brcmfmac`) | geplant |

**Auf Hardware ist noch nichts getestet.** Gebaut und geprüft sind bisher: der
Device Tree (kompiliert ohne eigene Warnungen), die Kernel-Config, ein
bitidentisch reproduzierbares initramfs, der Boot-Image-Packer und die
pmaports-Patches (lassen sich sauber anwenden). Für den Kernel selbst fehlt noch
der Cross-Compiler: heruntergeladen und signaturgeprüft, aber noch nicht
entpackt und ausgeführt.

### Aufbau

| Pfad | Inhalt |
|---|---|
| `docs/htc-m7/` | Bestandsaufnahme, Fehleranalyse, Hardware, Kernelstrategie, Build, Testplan |
| `kernel/patches/` | Device-Tree-Patch gegen `apq8064-mainline/linux@9e451475` |
| `kernel/config/` | Config-Fragment über der pmaports-Kernel-Config |
| `pmaports/patches/` | Patches für Nura-pmaports (Fix des Kernelpakets, Mainline-`device-htc-m7`) |
| `initramfs/` | `/init` für Stufe 1 und Hardware-Probe (nur lesend) |
| `scripts/` | Skripte zum Laden/Prüfen und Bauen, Boot-Image- und cpio-Writer |
| `sources.lock` | alle gepinnten Eingaben mit Commit-Hash oder Prüfsumme |

### Build

```sh
scripts/build.sh    # laden + prüfen, Kernel mit eingebettetem initramfs, boot.img
```

Ergebnisse landen in `out/`, Quellen und Toolchain in `work/` (beide von git
ignoriert). Kein Root nötig. Details:
[docs/htc-m7/05-build.md](docs/htc-m7/05-build.md).

Test auf dem Telefon nur im RAM, ohne etwas zu schreiben:
`fastboot boot out/boot-htc-m7-stage1.img`. Vor jedem Flashen
[docs/htc-m7/06-testplan.md](docs/htc-m7/06-testplan.md) lesen.

---

License: AGPL-3.0, see [LICENSE](LICENSE). Patches against upstream projects keep the
upstream license (Linux: GPL-2.0-only, pmaports: MIT).
