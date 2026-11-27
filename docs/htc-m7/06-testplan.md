# 6. Testplan auf Hardware

Grundsatz: Jeder Schritt, der etwas auf das Gerät schreibt, braucht eine
ausdrückliche Freigabe. Die Schritte sind so geordnet, dass zuerst nur gelesen
bzw. nur im RAM gebootet wird.

| Schritt | Schreibt auf das Gerät? | Freigabe |
|---|---|---|
| T0 Bestandsaufnahme | nein | – |
| T1 `fastboot boot` Stufe 1a | nein (nur RAM) | ja (Hardwaretest) |
| T2 Sicherung `boot` | nein (nur lesen) | – |
| T3 `fastboot flash boot` | **ja** | **ja, ausdrücklich** |

## T0 – Gerätezustand erfassen (nur lesen)

Im Bootloader (Leiser + Power):

```sh
fastboot getvar all 2>&1 | tee m7-getvar.txt
```

Wichtig: `version-bootloader` (hboot), `version-main`, `product`/`modelid`
(m7ul, m7_u, m7wls, m7wlv), `security` (S-ON/S-OFF), Entsperrstatus.

Falls TWRP installiert ist (liefert den Panel-Typ ohne neuen Kernel):

```sh
adb shell dmesg | grep -iE 'panel|PANEL ID' > m7-panel.txt
adb shell cat /proc/cmdline > m7-cmdline.txt
```

## T1 – Stufe 1a im RAM booten

```sh
fastboot boot out/boot-htc-m7-stage1.img
```

Erwartung: Das Splash-Logo bleibt stehen (Linux fasst das Display nicht an).
Am Host erscheint ein USB-Gerät `18d1:d001` „FalloutOS HTC One M7 (stage 1)“ mit

- seriellem Port (`/dev/ttyACM0`): `picocom /dev/ttyACM0` → Shell
- Netzwerk (CDC-NCM): Host bekommt per DHCP 172.16.42.2, dann
  `telnet 172.16.42.1`

Bericht holen:

```sh
cat /run/m7-probe.txt          # auf dem Gerät
```

Inhalt: hboot-ATAGs (Panel-Typ, RAM-Bänke, Cmdline), MDP4-Scan-out-Register
(nur wenn die MDP-Takte laufen), `/proc/iomem`, dmesg, pstore.

Mögliche Ergebnisse:

| Beobachtung | Bedeutung / nächster Schritt |
|---|---|
| hboot lehnt `fastboot boot` ab | weiter nur mit T2+T3 (Freigabe nötig) |
| kein USB-Gerät, kein Neustart | Kernel hängt früh; Gerät per Power 10 s aus, wieder starten, erneut T1 und `/sys/fs/pstore` lesen |
| Neustart | `ramoops` bei `0x8F100000`: beim nächsten T1 `ls /sys/fs/pstore` |
| Shell da | Bericht sichern, weiter mit Stufe 1b |

## T2 – Sicherung der Boot-Partition (vor jedem Flashen)

Aus TWRP:

```sh
adb shell 'dd if=/dev/block/platform/msm_sdcc.1/by-name/boot of=/sdcard/boot-orig.img'
adb pull /sdcard/boot-orig.img
sha256sum boot-orig.img
```

## T3 – Flashen (nur mit ausdrücklicher Freigabe)

```sh
fastboot flash boot out/boot-htc-m7-stage1.img
fastboot reboot
```

Zurück: `fastboot flash boot boot-orig.img`.

## Stufe 1b – Display-TTY

Mit den Werten aus `m7-probe` (Abschnitt „simple-framebuffer candidate“) kommt
in den DTS:

```dts
/ {
	chosen {
		#address-cells = <1>;
		#size-cells = <1>;
		ranges;

		framebuffer@<SRC_BASE> {
			compatible = "simple-framebuffer";
			reg = <SRC_BASE GROESSE>;
			width = <1080>;
			height = <1920>;
			stride = <SRC_STRIDE>;
			format = "r8g8b8";	/* je nach DMA_P CONFIG / Bytes pro Pixel */
		};
	};

	reserved-memory {
		splash_mem: memory@<SRC_BASE> {
			reg = <SRC_BASE GROESSE>;
			no-map;
		};
	};
};
```

Erfolgskriterium Meilenstein 1: Kernelmeldungen und Shell-Prompt auf dem
Display (tty1), Eingabe über die USB-Shell.
