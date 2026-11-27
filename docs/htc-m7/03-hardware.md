# 3. Hardware: Komponenten einzeln

SoC: Qualcomm APQ8064T (Snapdragon 600, 4× Krait 300), PMICs PM8921 + PM8821,
2 GiB LPDDR2, Adreno 320. Alle Angaben stammen aus dem Downstream-Kernel
(`arch/arm/mach-msm/board-m7*.c`) und sind **nicht** auf Hardware nachgemessen.

Legende Mainline-Status: ✅ Treiber vorhanden · ⚠️ Treiber vorhanden, aber
Gerätebeschreibung, Firmware oder Daten fehlen · ❌ kein Treiber.

## 3.1 Display

| | |
|---|---|
| Controller | MDP4 → DSI1 (4 Lanes), 1080×1920, 60 Hz |
| Panel-Varianten | per ATAG `0x4d534d74`: JDI/Samsung `0x00940065` (+ Rev. C2 `0x02…`, C2_1 `0x04…`, C2_2 `0x06…`), Sharp/Renesas `0x00940067`, Sharp/Renesas C1 `0x00940069`, JDI/Renesas `0x00940074` |
| Modus | **nur 0x940067 im Video-Mode** (hbp 58, hfp 100, hpw 10, vbp 4, vfp 4, vpw 2, Takt 860 MHz); alle anderen Command-Mode (hbp 27, hfp 38, hpw 10, vbp/vfp 4, vpw 2, 830 MHz) |
| Versorgung | LVS5 (1,8 V, `dsi1_vddio`), L2 (1,2 V, DSI-PLL), PM8921-GPIO 37 (+5 V) und 36 (−5 V) |
| GPIOs | Reset TLMM 31, TE TLMM 0 |
| Init-Sequenzen | `board-m7-display.c`, je Panel eigene DCS-Befehlslisten |

**Mainline:** MDP4- und DSI-Treiber vorhanden ✅, aber `mdp4_dsi_encoder.c`
kann **nur Video-Mode**. Ein Panel-Treiber für das M7 fehlt ❌.

- Stufe 1b: `simple-framebuffer` auf dem Scan-out-Puffer, den hboot
  hinterlässt. Bei Video-Mode-Panels ergibt das sofort ein TTY. Bei
  Command-Mode-Panels bleibt das Bild stehen, bis jemand DMA_P anstößt.
- Stufe 1c: eigener DRM-Panel-Treiber, zuerst für Sharp/Renesas 0x940067
  (Video-Mode, mit dem vorhandenen MDP4 machbar).
- Command-Mode-Panels: entweder Command-Mode-Unterstützung für MDP4 in
  drm/msm (größerer Aufwand) oder Prüfen, ob die Renesas-Controller per
  Init-Sequenz in den Video-Mode wechseln. Ob das geht, ist offen.

## 3.2 Hintergrundbeleuchtung

| | |
|---|---|
| Steuerung | Helligkeit per DCS 0x51 ans Panel (Panel-PWM) |
| Zusatz-IC | „pwm_i2c“ auf **GSBI2-I2C, Adresse 0x36** (`board-m7.c:5042`), Version in Register 0x1F; Init-Folge in `board-m7-display.c` (`pwmic_config`) |
| Enable | TLMM-GPIO 86 (`BL_HW_EN`) |
| Kennlinie | Helligkeit 0–255 → PWM min 6 (IC ≥ A2) bzw. 11, Default 69/81, max 255 |

**Mainline:** ⚠️ Der Hersteller des IC ist nicht bekannt, es gibt keinen
passenden Treiber. Vorschlag: Helligkeit über den Panel-Treiber
(DCS-Backlight), Freigabe des IC als kleiner I2C-Treiber oder im Panel-Treiber.
Stufe 1 fasst weder IC noch GPIO an, die Beleuchtung bleibt also so, wie hboot
sie für das Splash gesetzt hat.

## 3.3 Touchscreen

| | |
|---|---|
| Chip | Synaptics ClearPad 3K (`synaptics_3200`), RMI4-Protokoll |
| Bus | **GSBI3-I2C** (TLMM 8/9), Adresse **0x20** (`board-m7.c:3095`) |
| IRQ / Reset | TLMM 34 (`TP_ATTz`, low aktiv) / TLMM 85 |
| Versorgung | L15 (Low-Power-Modus, `board-m7.c:2254`); Hauptversorgung noch unklar |
| Bereich | Sensor 1620×2880 auf Display 1080×1920; die kapazitiven Tasten (Home/Back) liegen im Sensorbereich unter dem Display |

**Mainline:** ✅ `rmi4_i2c` mit F11/F12 ist in der Config. Der DTS-Knoten folgt
in Meilenstein 2 (Vorlage: jflte). Absichtlich noch nicht aktiv: Bei falscher
IRQ-Konfiguration droht ein IRQ-Sturm, der Stufe 1 lahmlegen würde.

## 3.4 Audio

| | |
|---|---|
| Codec | WCD9310 („Tabla“) über SLIMbus (`board-m7.c:2084`) |
| Verstärker | 2× NXP TFA9887 (GSBI1-I2C 0x34/0x35, „BoomSound“), RT5501 (0x78), TPA6185 (0x63) |
| I2S | MI2S RX auf TLMM 27/28/32 (zu den TFA9887) |

**Mainline:** ❌ kein Treiber für WCD9310, TFA9887, RT5501 oder TPA6185. Der
APQ8064-SLIMbus-Controller (`slim-qcom-ctrl`) ist aus dem Kernel entfernt, im
Fork liegt nur noch `qcom-ngd-ctrl`. Für eine reine Shell ohne Ton ist das nicht
nötig. Am ehesten realistisch wäre ein Lautsprecherpfad über MI2S und die TFA9887,
das bedeutet aber neue Treiber und Firmware.

## 3.5 WLAN

| | |
|---|---|
| Chip | Broadcom BCM4335 (802.11ac) über **SDIO auf SDCC3** (`board-m7-storage.c:530`) |
| Steuerung | `WL_REG_ON` PM8921-GPIO 16, Host-Wake PM8921-GPIO 38, 32-kHz-Takt PM8921-GPIO 43 |
| Firmware (Android) | `/system/etc/firmware/fw_bcm4335_b0.bin`, NVRAM `/system/etc/calibration` |

**Mainline:** ⚠️ `brcmfmac` kennt den BCM4335 (`brcmfmac4335-sdio`), als Modul
in der Config. Es fehlen der DTS-Knoten (`mmc-pwrseq-simple` mit GPIO 16, 32 kHz
aus PM8921-GPIO 43; Vorlage jflte) und die Firmware. Die Android-Firmware muss
vom Gerät kommen und darf vermutlich nicht weiterverteilt werden.

## 3.6 Übrige Komponenten (für Stufe 1 nötig)

| Komponente | Daten | Mainline / Stufe 1 |
|---|---|---|
| Tasten | Power TLMM 26, Lauter TLMM 11, Leiser TLMM 77 (alle low aktiv, Pull-up) | ✅ `gpio-keys` im DTS |
| eMMC | SDCC1, 8 Bit, vmmc L5 2,95 V, vqmmc S4 1,8 V | ✅ im DTS; Stufe 1 liest nur |
| USB | ChipIdea, PHY mit L3 3,075 V / L4 1,8 V, ID-Pin PM8921-GPIO 7 | ✅ im DTS als `peripheral` (Debug-Kanal) |
| PMIC-IRQ | PM8921 an TLMM 74; PM8821 direkt an GIC SPI 15 (anders als jflte) | ✅ PM8921; PM8821 in Stufe 1 weggelassen |
| RAM-Console | `0x8F100000`, 896 KiB (`msm_iomap-8960.h:136`) | ✅ als `ramoops` |
| Modem | externes MDM9215 über HSIC | ❌ nicht geplant |
| GPU | Adreno 320 | ⚠️ freedreno vorhanden, für TTY nicht nötig |
