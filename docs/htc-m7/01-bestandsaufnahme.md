# 1. Bestandsaufnahme

Untersucht am 2026-11-27, pmaports `3156402c` (main, 2026-11-27).

## 1.1 Pakete in pmaports

| Paket | Ort | Version | Zustand |
|---|---|---|---|
| `device-htc-m7` | `device/archived/` | pkgver 4 | archiviert 2026-06-21 („unmaintained“) |
| `linux-htc-m7` | `device/archived/` | 3.4.10-r5 | archiviert, Downstream-Kernel |
| `linux-postmarketos-qcom-apq8064` | `device/testing/` | 7.2-r0 | gepflegt (Maintainer: Alexandre Minette), Mainline-Fork |
| `lk2nd` (`lk2nd-msm8960`) | `main/` | 23.1 | gepflegt; **kein** Eintrag für das M7 |
| `msm-fb-refresher` | `main/` | 0.2-r7 | existiert, wird von `device-htc-m7` **nicht** genutzt |

Historie von `device-htc-m7`/`linux-htc-m7`: eingeführt mit MR !306 (2019-04-07,
Autor tdeo), danach nur noch treeweite Wartungscommits; 2025-05-15 nach
„downstream“ einsortiert, 2026-06-21 archiviert.

### device-htc-m7 (archiviert)

- `deviceinfo_format_version="0"`, armv7, 1080×1920
- Boot-Image: base `0x80600000`, kernel `+0x8000`, ramdisk `+0x01800000`,
  second `+0x00f00000`, tags `+0x100`, pagesize 2048
- kein DTB (3.4-Kernel mit Board-Files), kein lk2nd
- `kernel-cmdline.conf`: `console=none androidboot.hardware=qcom user_debug=31 buildvariant=userdebug`
- depends: `postmarketos-base linux-htc-m7 mkbootimg`, kein `msm-fb-refresher`, keine Firmware

### linux-htc-m7 (archiviert)

- Quelle: `LineageOS/android_kernel_htc_m7` @ `f6eb6496406f5a06cdd4716e494082d78df70e83`
  (Tarball-sha512 aus dem APKBUILD stimmt, am 2026-11-27 geprüft)
- Config basiert auf `arch/arm/configs/cyanogenmod_m7_defconfig`
- Patches: Cross-Compile-Makefile, `lzop -6`, gcc8 `put_user`, `-std=gnu89`,
  ARM 8933/1 Section-Flags, `piggy.lzo.S`
- Display-Treiber: `msm_fb` (MDP4, DSI), kein DRM
- Nicht von mir gebaut. Issue #3264 („can't compile with pmbootstrap“, 2024) und
  #3237 (GCC-Warnungen) deuten auf Probleme mit aktuellen Compilern hin.

### linux-postmarketos-qcom-apq8064 (Mainline)

- Fork `github.com/apq8064-mainline/linux`, Branch `qcom-apq8064-v7.2`,
  gepinnt auf `9e4514751f87a2f2034c6707396794a74337866c` (2026-10-18)
- Build mit clang/LLVM, Config `config-postmarketos-qcom-apq8064.armv7`
- DTS im Fork: asus-nexus7-flo, cm-qs600, ifc6410, lg-nexus4-mako,
  samsung-jflte, sony-xperia-lagan-yuga, **kein htc-m7**
- Genutzt von `device-asus-flo` und `device-samsung-jflte` (beide mit lk2nd)
- **Fehler im APKBUILD:** Die Quell-URL `archive/$_tag/$_commit.tar.gz`
  liefert den Branch-HEAD (am 2026-11-27: `cc2a6a24`, 2026-11-13) statt `9e451475`.
  Die sha512 passt deshalb nicht mehr, das Paket ist so nicht baubar.
  Geprüft mit `git get-tar-commit-id`. Korrigiert in pmaports-Patch 0001.

## 1.2 Wiki und Issues

Wiki „HTC One M7 (htc-m7)“ (wiki.nura.eco): Kategorie archived, Kernel 3.4.10,
USB-Netz Y, Flashen P, Display P. Hinweise aus dem Wiki:

- Nur Konsolenbetrieb über SSH via USB, auf dem Display bleibt das Splash-Logo.
- Display lässt sich manuell aktivieren:
  `echo 100 > …/msm_fb.590593/leds/lcd-backlight/brightness` und
  `cat …/fb0/modes > …/fb0/mode`, „funktioniert manchmal nicht“.
- „Direct flashing doesn't seem to work“, Installation per TWRP-Sideload.
- Behauptung eines Nutzers, Mainline/lk2nd brauche **S-OFF**. Dafür gibt es
  keinen technischen Beleg (siehe [04-kernelstrategie.md](04-kernelstrategie.md#s-on)).

Issues (pmaports):

| # | Titel | Inhalt |
|---|---|---|
| 717 | Screen driver issues? (2020, geschlossen) | Display schwarz, `cat /dev/random > /dev/fb0` zeigt aber Bild |
| 2538 | htc-m7 doesnt shows up screen (2024, offen) | „either htc m7 reboots, or just starts with black/no screen“ |
| 2794 | ejected after five seconds of telnet (2024, offen) | Telnet im initramfs bricht nach ~5 s ab |
| 2774 | debugging profile for reboots in loop (2024, geschlossen) | Bootschleife, `console=tty0` hilft nicht |
| 3264 / 3237 | Build-Fehler bzw. -Warnungen (2024) | |
| 4391 | boot without several partitions / S-ON (2026, offen) | Frage nach Mainline unter S-ON |

Logs und Kommentare der Issues sind nur angemeldet abrufbar (HTTP 401/404) und
wurden deshalb nicht ausgewertet.

## 1.3 Vergleichsgeräte (gleicher SoC)

| Gerät | Kernel | Bootweg | Relevanz |
|---|---|---|---|
| Samsung Galaxy S4 (jflte) | apq8064 7.2 | lk2nd, angehängter DTB | gleiche WLAN- (BCM4335/SDCC3) und Touch-Anbindung (RMI4/GSBI3), Vorlage für den DTS |
| Nexus 7 2013 (flo) | apq8064 7.2 | lk2nd | Vorlage USB/eMMC |
| HTC One M8 (archiviert) | msm8974 | lk2nd-Variante mit HTC-Offsets, rootfs auf `system` | Beleg für HTC-Mainline unter hboot |

## 1.4 Build-Host

Ubuntu 24.04, x86_64, 8 Kerne, 39 GiB RAM, ~20 GiB frei (95 % belegt).
Vorhanden: gcc 13 (Host), make, bison, flex, bc, perl, python3, cpio, xz, zstd,
gpg, git. **Nicht** vorhanden: ARM-Cross-Compiler, clang/lld, dtc, pmbootstrap,
fastboot/adb, docker-Daemon. `sudo` verlangt ein Passwort.
