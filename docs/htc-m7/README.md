# HTC One M7 (htc-m7) – Bring-up für FalloutOS

Ziel: Bootloader → Linux-Kernel → Display → Linux-TTY → Shell, ohne X11/Wayland.
Nächster Meilenstein: Touchscreen und virtuelle Tastatur.

Stand: 2026-11-27, Branch `htc-m7-bringup`.

## Ergebnis in Kürze

- Der bisherige Port (`device-htc-m7` + `linux-htc-m7`, Downstream-Kernel 3.4.10)
  ist seit 2026-06-21 in pmaports **archiviert** und war nie gepflegt.
  Das schwarze Display hat zwei belegte Ursachen im Downstream-Treiber und
  in der Kernelkonfiguration ([02-fehleranalyse.md](02-fehleranalyse.md)).
- Den 3.4-Kernel zu reparieren lohnt nicht. Ziel ist der Mainline-Kernel
  **Linux 7.2** (`apq8064-mainline`-Fork, den Nura/pmaports bereits für
  Nexus 7 2013 und Galaxy S4 nutzt), ergänzt um einen neuen Device Tree für das
  M7 ([04-kernelstrategie.md](04-kernelstrategie.md)).
- Stufe 1 ist vorbereitet: Device Tree, Kernel-Config-Fragment, ein initramfs,
  das nur im RAM läuft, ein Boot-Image-Packer und reproduzierbare Build-Skripte.
  Die Stufe liefert eine Shell über USB und liest die fehlenden Hardwaredaten aus
  (Panel-Typ, Scan-out-Adresse des Displays).
- Der **Kernel selbst ist noch nicht kompiliert**: Der Cross-Compiler wurde
  heruntergeladen und verifiziert, sein Entpacken und Ausführen aber noch nicht
  freigegeben. **Auf Hardware ist noch nichts getestet.**

## Status: gebaut vs. auf Hardware getestet

| Komponente | Gebaut / geprüft | Auf Hardware getestet |
|---|---|---|
| Downstream `linux-htc-m7` 3.4.10 | nicht gebaut (laut Issues #3264, #3237 Build-Probleme mit aktuellem GCC) | laut Wiki: bootet, nur SSH über USB, Display schwarz |
| Device Tree `qcom-apq8064-htc-m7.dts` | ✅ mit `dtc` aus dem Kernelbaum kompiliert, `W=1` ohne eigene Warnungen | ❌ |
| Kernel-Config (pmaports-Basis + Fragment) | ✅ `olddefconfig`, alle Fragmentwerte verifiziert | ❌ |
| Kernel zImage 7.2 | ❌ **nicht kompiliert** (Toolchain nicht freigegeben) | ❌ |
| Stage-1-initramfs | ✅ gebaut, bitidentisch reproduzierbar (2 Builds, verschiedene umask) | ❌ |
| Boot-Image-Packer `scripts/bootimg.py` | ✅ mit Testdaten geprüft (Header v0, 1632 Bytes, ID, Größenwächter) | ❌ |
| Stage-1-`boot.img` | ❌ (braucht den Kernel) | ❌ |
| pmaports-Patches (3 Stück) | ✅ lassen sich sauber auf den gepinnten Commit anwenden | ❌ |
| pmaports-Pakete (`pmbootstrap build`) | ❌ nicht gebaut (pmbootstrap braucht sudo) | ❌ |

Hardware einzeln: [03-hardware.md](03-hardware.md).

## Dokumente

1. [01-bestandsaufnahme.md](01-bestandsaufnahme.md): was es gibt, Versionen, Herkunft
2. [02-fehleranalyse.md](02-fehleranalyse.md): schwarzes Display und Neustarts
3. [03-hardware.md](03-hardware.md): Display, Backlight, Touch, Audio, WLAN (+ Tasten, eMMC, USB, RAM)
4. [04-kernelstrategie.md](04-kernelstrategie.md): Entscheidung, Risiken, Stufenplan
5. [05-build.md](05-build.md): reproduzierbarer Build, Abhängigkeiten
6. [06-testplan.md](06-testplan.md): Hardwaretests mit Freigabepunkten (nichts wird ohne Freigabe geflasht)

## Änderungen in diesem Branch

Am Originalcode wird nichts direkt verändert. Jede Änderung an Upstream-Code
liegt als `git format-patch`-Datei vor und lässt sich auf den gepinnten Commit
anwenden.

| Datei | Inhalt |
|---|---|
| `kernel/patches/0001-ARM-dts-qcom-apq8064-add-HTC-One-M7-stage-1.patch` | neuer DTS + Makefile-Eintrag, gegen `apq8064-mainline/linux@9e451475` |
| `kernel/config/htc-m7-bringup.config` | Config-Fragment über der pmaports-Config |
| `pmaports/patches/0001-…-fix-source-add-HTC-O.patch` | `linux-postmarketos-qcom-apq8064`: Quell-URL repariert, M7-DTS ergänzt |
| `pmaports/patches/0002-…-move-from-archived-to-testing.patch` | `device-htc-m7`: reine Verschiebung |
| `pmaports/patches/0003-…-switch-to-the-mainline-apq8064-kernel.patch` | `device-htc-m7`: auf Mainline umgestellt |
| `initramfs/` | `/init`, `m7-probe`, `udhcpd.conf` für Stufe 1 |
| `scripts/` | Fetch/Build-Skripte, `bootimg.py`, `mkcpio.py` |
| `sources.lock` | alle gepinnten Eingaben mit Commit-Hash bzw. Prüfsumme |

## Upstream-relevante Befunde

- **pmaports-Bug:** `linux-postmarketos-qcom-apq8064` lädt über
  `archive/$_tag/$_commit.tar.gz` den aktuellen Branch-HEAD statt des gepinnten
  Commits, deshalb schlägt die sha512 inzwischen fehl. Der Fix steckt in
  pmaports-Patch 0001 und wäre einen Merge Request wert.
- postmarketOS heißt seit 2026-09-27 **Nura**. `gitlab.postmarketos.org`
  leitet auf `gitlab.nura.eco` um (gleicher Host bei OSUOSL).
