# 2. Fehleranalyse: schwarzes Display und Neustarts

Quellen: `LineageOS/android_kernel_htc_m7@f6eb6496` (Pfadangaben relativ dazu)
und `device/archived/linux-htc-m7/config-htc-m7.armv7`.

## 2.1 Schwarzes Display (Downstream-Kernel) – Ursache belegt

Drei Ursachen kommen zusammen, jede reicht allein für ein dunkles bzw.
eingefrorenes Bild.

### a) Die Hintergrundbeleuchtung wird nie eingeschaltet

`drivers/video/msm/msm_fb.c`:

- `:798`: beim Probe wird `mfd->bl_level = 0` gesetzt.
- `:1354`: `msm_fb_set_backlight()` merkt sich einen Helligkeitswert nur
  (`unset_bl_level`), solange `bl_updated == 0`, und schaltet nichts.
- `:2585`: erst ein **Pan/Commit** (`msm_fb_pan_display_ex`) plant den
  `bl_workqueue_handler` (`:2436`) ein, der den gemerkten Wert anwendet und
  `bl_updated = 1` setzt.

Unter Android schreibt der Lights-HAL die Helligkeit und SurfaceFlinger pannt
ständig. Unter postmarketOS ohne GUI passiert beides nicht, die Beleuchtung bleibt
also bei 0. Genau das umgeht der Workaround aus dem Wiki: `brightness` schreiben
setzt `unset_bl_level`, das Neuschreiben von `mode` löst über `set_par` einen Pan aus.

Die eigentliche Helligkeit schreibt `m7_set_backlight()`
(`arch/arm/mach-msm/board-m7-display.c`) per DCS 0x51 ans Panel und
konfiguriert zusätzlich einen PWM-IC per I2C (siehe [03-hardware.md](03-hardware.md)).

### b) Command-Mode-Panels brauchen für jedes Bild einen Anstoß

Das M7 wird mit mehreren Panels ausgeliefert. hboot meldet den Typ per ATAG
`0x4d534d74` (`devices_htc.c:329`). Nur **Sharp/Renesas `0x940067`** läuft im
Video-Mode, und nur für dieses Panel aktiviert der Kernel Continuous Splash
(`board-m7-display.c:2943`). JDI/Samsung (`0x?940065`), Sharp C1 (`0x940069`) und
JDI/Renesas (`0x940074`) sind **Command-Mode**-Panels: Das MDP schickt nur dann
ein Bild, wenn ein Pan einen DMA-Transfer anstößt. Schreibt fbcon oder
`cat > /dev/fb0` direkt in den Framebuffer, kommt davon nichts am Panel an.
Dafür gibt es `msm-fb-refresher`, das `device-htc-m7` aber nicht einbindet.

Das erklärt auch „funktioniert manchmal nicht“: Ein einzelnes Neuschreiben von
`mode` erzeugt genau ein Bild, danach steht die Anzeige wieder.

### c) Es gibt keine Text-Konsole auf dem Display

- `CONFIG_FRAMEBUFFER_CONSOLE` ist **nicht gesetzt**: Selbst bei
  funktionierendem Panel erscheint kein TTY.
- `kernel-cmdline.conf` enthält `console=none`.

### Folgerung für den Downstream-Kernel

Reparierbar wäre das mit `FRAMEBUFFER_CONSOLE=y`, `console=tty0`, einem
Kernel-Patch, der die Beleuchtung beim Probe mit einem Standardwert setzt, und
`msm-fb-refresher` für Command-Mode-Panels. Es bliebe aber ein Kernel 3.4 aus
2013, der mit aktuellen Compilern Probleme macht und den aktuelle Userspace-
Komponenten zunehmend nicht mehr unterstützen. Deshalb wird dieser Weg nicht
verfolgt ([04-kernelstrategie.md](04-kernelstrategie.md)).

## 2.2 Neustarts (Downstream-Kernel) – Ursache nicht belegt

Gemeldet: „either htc m7 reboots, or just starts with black/no screen“ (#2538),
Telnet bricht nach etwa 5 s ab (#2794), Bootschleife (#2774). Die angehängten
Logs sind nur angemeldet abrufbar. Ohne Log vom Gerät gibt es nur Hypothesen,
nach Plausibilität geordnet:

| # | Hypothese | Indiz | Prüfung |
|---|---|---|---|
| H1 | Kernel-Panic, danach automatischer Neustart | `CONFIG_PANIC_TIMEOUT=5`: Neustart 5 s nach jeder Panic, passt zu „nach 5 s weg“ | `/proc/last_kmsg` in TWRP direkt nach dem Neustart lesen (`CONFIG_ANDROID_RAM_CONSOLE=y`, Bereich `0x8F100000`) |
| H2 | Panic im Subsystem-Restart (externes Modem MDM9215 über HSIC, PIL-Firmware) | `subsystem_restart.c` ruft `panic()` z. B. bei „died during powerup“ oder zu vielen Abstürzen; ohne Android-Dienste (`ks`, `mdm_helper`) bootet das Modem nie | dto. |
| H3 | Watchdog-Bark | `CONFIG_MSM_WATCHDOG=y`, ein blockierter Kern löst ihn aus | dto., TZ-Log hinter dem RAM-Console-Bereich |
| H4 | Kein Neustart, nur USB-Neuaufbau | Das initramfs konfiguriert das USB-Gadget um, die Host-Seite sieht einen Abbruch | prüfen, ob das Gerät danach wieder enumeriert |

Die Standard-Restart-Stufe ist `RESET_SUBSYS_INDEPENDENT`
(`subsystem_restart.c:776`), ein einzelner Subsystem-Absturz startet also nicht
automatisch das ganze Gerät neu, die Panic-Pfade aber schon.

## 2.3 Risiken für Mainline, die vorab entschärft wurden

Diese Punkte betreffen den neuen Kernel und sind im Device Tree bereits
berücksichtigt:

1. **Speicherlayout.** Der Vendor-Kernel ignoriert die RAM-Angaben von hboot und
   setzt drei feste Bänke (`board-m7.c:5477`, `m7_fixup`):
   `0x80600000 +134 MiB`, `0x89000000 +63 MiB`, `0x90000000 +1792 MiB`.
   Mainline übernimmt dagegen per `ARM_ATAG_DTB_COMPAT` die ATAGs von hboot.
   Meldet hboot RAM ab `0x80000000`, entpackt der Decompressor den Kernel nach
   `0x80008000`, also in SMEM, und Lücken mit Firmware/TZ-Daten würden als RAM
   genutzt. Beides führt typischerweise zu sofortigen Resets (XPU-Verletzung).
   Gegenmaßnahme: `/chosen/linux,usable-memory-range = <0x80600000 0x7fa00000>`.
   Die Eigenschaft wertet sowohl der Decompressor
   (`arch/arm/boot/compressed/fdt_check_mem_start.c`) als auch der Kernel
   (`drivers/of/fdt.c`, `early_init_dt_check_for_usable_mem_range`) aus, und
   `atags_to_fdt` überschreibt sie nicht. Zusätzlich sind die Lücken als
   `no-map` reserviert.
2. **Ramdisk-Offset.** Mit dem Vendor-Wert `0x01800000` liegt die Ramdisk 24 MiB
   hinter dem Kernel. Ein entpackter Mainline-Kernel ist größer und würde sie
   überschreiben. Deshalb neu: `0x04000000`. Stufe 1 bettet das initramfs
   zusätzlich in den Kernel ein und hängt nicht von dieser Adresse ab.
3. **Display-Zustand.** Ohne Panel-Treiber darf Linux die Takte und Spannungen,
   die hboot für das Display eingeschaltet hat, nicht abschalten:
   `clk_ignore_unused pd_ignore_unused regulator_ignore_unused`, und die
   Display-Regler sind im DTS bewusst nicht beschrieben.
4. **Watchdog.** Läuft der Watchdog bei der Übergabe, erkennt `qcom_wdt` das
   und der Watchdog-Core bedient ihn (`CONFIG_QCOM_WDT=y`).
