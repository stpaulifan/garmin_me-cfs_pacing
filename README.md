# Pacing für Garmin Vivoactive 5

Zwei Connect-IQ-Apps, die Menschen mit **ME/CFS** beim **Pacing** helfen: den Puls im Alltag unter einer persönlichen Grenze halten, um Crashs nach Belastung (PEM) zu vermeiden.

| Projekt | Typ | Funktion |
|---|---|---|
| [`PacingFace`](PacingFace/) | Watchface | Uhrzeit (digital oder analog) mit **Puls-Ampel** als Ring. Immer sichtbar, ohne Vibration. |
| [`PacingAlarm`](PacingAlarm/) | Geräte-App | Prüft den Puls jede Sekunde und **vibriert**, wenn er zu lange über der Grenze liegt. |

> ⚠️ Kein Medizinprodukt. Die passende Pulsgrenze sollte mit einer Ärztin, einem Arzt oder einer Physiotherapeutin abgestimmt werden.

## Funktionen

### Puls-Grenze
- Standard: **Ruhepuls + 15 bpm**. Der Ruhepuls kommt automatisch aus dem Garmin-Profil.
- Alternativ: **feste Grenze** (Standard 100 bpm).
- Ampel: 🟢 unter der Grenze · 🟡 ab Grenze −5 · 🔴 über der Grenze

### PacingFace (Watchface)
- Stil **digital** oder **analog**
- Ampel-Ring, Datum, aktueller Puls / Grenze
- Stromsparende Always-on-Ansicht (AMOLED)
- **Einstellungen direkt auf der Uhr:** lange auf das Zifferblatt drücken → *Pacing Face* → *Anpassen*
  - Stil: Digital / Analog
  - Grenze: Ruhepuls + Aufschlag / feste Grenze
  - Aufschlag: +10 / +15 / +20 / +25 / +30 bpm
  - Feste Grenze: 70–140 bpm in 5er-Schritten

### PacingAlarm (App)
- Vibriert, wenn der Puls länger als **20 s** über der Grenze liegt, und wiederholt die Warnung alle **60 s**
- Zeigt Puls, Grenze, Ruhepuls und die gesamte **Zeit über der Grenze**
- Grenze am Gerät ändern: **nach unten wischen = +1**, **nach oben wischen = −1**

## Projektstruktur

```
.
├── PacingFace/
│   ├── manifest.xml
│   ├── monkey.jungle
│   ├── resources/        # Icon, Texte, Einstellungen (properties.xml)
│   └── source/           # PacingFaceApp, PacingFaceView, PacingSettings
├── PacingAlarm/
│   ├── manifest.xml
│   ├── monkey.jungle
│   ├── resources/
│   └── source/           # PacingAlarmApp, PacingMonitor, PacingView
├── CLAUDE.md             # Projektkontext für Claude Code
└── README.md
```

## Einstellungen (Standardwerte)

In `resources/settings/properties.xml` des jeweiligen Projekts:

| Schlüssel | Standard | Bedeutung | Face | Alarm |
|---|---|---|:-:|:-:|
| `style` | 0 | 0 = digital, 1 = analog | ✓ | |
| `mode` | 1 | 0 = feste Grenze, 1 = Ruhepuls + Aufschlag | ✓ | ✓ |
| `fixedLimit` | 100 | feste Grenze (bpm) | ✓ | ✓ |
| `offset` | 15 | Aufschlag auf den Ruhepuls (bpm) | ✓ | ✓ |
| `delaySec` | 20 | Warnung erst nach … s über der Grenze | | ✓ |
| `repeatSec` | 60 | Warnung wiederholen alle … s | | ✓ |

> Per USB installierte Apps lassen sich **nicht** über die Connect-IQ-Handy-App einstellen. Deshalb gibt es das Menü auf der Uhr (Watchface) bzw. das Wischen (Alarm-App).

## Voraussetzungen

- [Connect IQ SDK Manager](https://developer.garmin.com/connect-iq/sdk/) mit einem aktuellen SDK und dem Gerät **vivoactive 5**
- Java 17+
- VS Code (oder Code - OSS) mit der Erweiterung **Monkey C** von Garmin
- Ein Developer Key (`Monkey C: Generate a Developer Key`), **nicht im Repo speichern**

## Bauen

In VS Code den jeweiligen **Projektordner** öffnen (`PacingFace` oder `PacingAlarm`) → `Strg+Shift+P` → **Monkey C: Build for Device** → `vivoactive5`.

Oder im Terminal:

```bash
SDK=$(cat ~/.Garmin/ConnectIQ/current-sdk.cfg)
KEY=~/.Garmin/ConnectIQ/developer_key
mkdir -p build
for p in PacingFace PacingAlarm; do
  "$SDK/bin/monkeyc" -d vivoactive5 -f $p/monkey.jungle -o build/$p.prg -y "$KEY" -w
done
```

## Simulator

In VS Code **F5** drücken, oder `"$SDK/bin/monkeydo" build/PacingFace.prg vivoactive5`. Für den Simulator mit `-d vivoactive5_sim` bauen.

- Puls simulieren: *Simulation → FIT Data → Simulate Data* oder *Activity Data*
- Einstellungen ändern: *File → Edit Persistent Storage → Edit Application.Properties data*

### Arch / CachyOS: Simulator in Distrobox

Der Simulator braucht `libwebkit2gtk-4.0`, die es in den Arch-Repos nicht mehr gibt. Abhilfe ist eine Ubuntu-Box:

```bash
distrobox create -n ciq -i ubuntu:22.04
distrobox enter ciq
sudo apt update
sudo apt install -y libwebkit2gtk-4.0-37 libjpeg8 libusb-1.0-0 \
  libsm6 libice6 libxext6 libxrender1 libxtst6 libxi6
"$(cat ~/.Garmin/ConnectIQ/current-sdk.cfg)/bin/simulator"
```

Läuft der Simulator, verbindet sich VS Code (F5) bzw. `monkeydo` vom Host automatisch mit ihm.

## Auf die Uhr übertragen

1. Uhr per USB anschliessen. Sie erscheint als MTP-Gerät, unter KDE in Dolphin (Paket `kio-extras`).
2. `build/PacingFace.prg` und `build/PacingAlarm.prg` nach **`Internal Storage/GARMIN/APPS/`** kopieren.
3. Uhr auswerfen und abstecken.
4. Watchface auswählen (lange auf das Zifferblatt drücken) bzw. *Pacing Alarm* in der App-Liste starten.

> Updates müssen mit **demselben Developer Key** signiert sein, sonst lässt sich die alte Version nicht ersetzen.

## Grenzen der Lösung

- Watchfaces dürfen nicht vibrieren, deshalb gibt es die separate Alarm-App.
- Die Alarm-App warnt nur, solange sie geöffnet ist. Hintergrunddienste dürfen höchstens alle 5 Minuten laufen, ein Echtzeit-Alarm ist im Hintergrund also nicht möglich.
- Das Watchface aktualisiert sich im Ruhemodus etwa einmal pro Minute.
- Der Puls am Handgelenk reagiert bei schnellen Belastungswechseln verzögert.

## Ideen

- [ ] Gemeinsame Logik in `shared/` auslagern (`base.sourcePath = source;../shared`)
- [ ] Tageszusammenfassung „Minuten über Grenze heute“
- [ ] Einstellungsmenü auch für die Alarm-App
- [ ] Body Battery / Stress im Watchface
