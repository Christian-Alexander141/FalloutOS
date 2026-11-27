# 4. Kernelstrategie

## 4.1 Entscheidung: Mainline 7.2 statt Downstream 3.4

| Kriterium | Downstream 3.4.10 reparieren | Mainline 7.2 (apq8064-Fork) |
|---|---|---|
| Display-TTY | machbar: fbcon, Backlight-Patch, Refresher | machbar: simplefb (Stufe 1b), danach Panel-Treiber |
| Wartbarkeit | Vendor-Kernel aus 2013, Board-Files, keine Updates | aktuell, DT-basiert, Fork von Nura gepflegt, nah an Upstream |
| Compiler | braucht Altlast-Patches, Build-Probleme gemeldet | GCC 15 / clang 23 |
| Userspace | aktuelle Pakete setzen neuere Kernel voraus | unproblematisch |
| Touch | HTC-Treiber vorhanden | `rmi4` vorhanden, nur DT nötig |
| WLAN | `bcmdhd` vorhanden | `brcmfmac` vorhanden, DT + Firmware nötig |
| Audio | vorhanden | fehlt (siehe 03) |
| Aufwand bis zur Shell | gering | mittel, Hardwaredaten fehlen noch |

Für ein dauerhaft wartbares System kommt nur Mainline in Frage. Den
Downstream-Kernel brauche ich höchstens als Werkzeug, um Daten auszulesen. Dafür
reicht aber das initramfs von Stufe 1 oder TWRP.

Den M7-Device-Tree lege ich in den bestehenden `apq8064-mainline`-Fork
(Paket `linux-postmarketos-qcom-apq8064`) statt einen eigenen Kernel zu pflegen.
Damit läuft das M7 über dieselbe Kernelversion und Config wie flo und jflte.

## 4.2 Bootweg: hboot direkt, lk2nd später

hboot lädt ein Android-Boot-Image v0 und übergibt ATAGs. Mainline braucht einen
DTB, der deshalb an das zImage angehängt wird (`ARM_APPENDED_DTB` und
`ARM_ATAG_DTB_COMPAT` sind in der Config aktiv). lk2nd kennt das M7 nicht
(`lk2nd/device/dts/msm8960/bundle.dts` in 23.1: nur flo und Samsung-Geräte) und
bräuchte wie beim M8 eine eigene Variante mit den HTC-Offsets. lk2nd ist erst
sinnvoll, wenn mehrere Kernel bequem wählbar sein sollen.

<a id="s-on"></a>
### S-ON

Die Behauptung im Wiki, Mainline brauche S-OFF, hat keinen erkennbaren
technischen Grund. Unter S-ON mit entsperrtem Bootloader (htcdev) bleiben
`boot`, `recovery` und `system` beschreibbar. Mehr braucht dieser Ansatz nicht:
Kernel und initramfs liegen in `boot`, ein späteres rootfs in `system`
(wie beim HTC M8). Wahrscheinlicher scheiterten frühere Versuche am
Speicherlayout (siehe [02-fehleranalyse.md](02-fehleranalyse.md#23-risiken-für-mainline-die-vorab-entschärft-wurden)).
Belegt ist das erst nach einem Test. Ob hboot `fastboot boot` (nur RAM)
zulässt, ist ebenfalls offen.

## 4.3 Stufenplan

| Stufe | Ziel | Inhalt | Status |
|---|---|---|---|
| 1a | Kernel bootet, Shell über USB, Daten auslesen | DTS ohne Display, initramfs im Kernel, `m7-probe` | vorbereitet, Kernel noch nicht kompiliert |
| 1b | **TTY auf dem Display** | `simple-framebuffer` mit Adresse/Format aus 1a | wartet auf 1a |
| 1c | Display unabhängig von hboot | DRM-Panel-Treiber (zuerst 0x940067), Backlight | wartet auf Panel-Typ |
| 2 | Touch + virtuelle Tastatur | RMI4-Knoten auf GSBI3, Konsolen-Bildschirmtastatur (z. B. `fbkeyboard` oder `buffyboard`) | geplant |
| 3 | WLAN | `brcmfmac` auf SDCC3, Firmware vom Gerät | geplant |
| 4 | Nura-Integration | rootfs auf `system`, UI „none“, pmaports-Pakete | Patches vorbereitet |
| – | Audio | neue Treiber nötig | zurückgestellt |

## 4.4 Offene Fragen, die nur das Gerät beantwortet

1. Welche Panel-Variante ist verbaut? (ATAG `0x4d534d74`, liest `m7-probe`, oder
   in TWRP: `dmesg | grep -i panel`)
2. Adresse, Größe, Stride und Format des hboot-Framebuffers (MDP4 DMA_P,
   liest `m7-probe`)
3. Welche RAM-Bänke meldet hboot per ATAG? (liest `m7-probe`)
4. Lässt hboot `fastboot boot` zu? Welche hboot-Version, S-ON oder S-OFF,
   welche Variante (m7ul/m7_u/m7wls/m7wlv)? (`fastboot getvar all`)
