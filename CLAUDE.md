# Pacing für Garmin Vivoactive 5 (ME/CFS)

Kommunikation mit mir auf **Deutsch**. Code-Kommentare ebenfalls Deutsch.

## Ziel

Connect-IQ-Apps für eine **Garmin Vivoactive 5**, die eine Person mit ME/CFS beim **Pacing** unterstützen: Puls unter einer Grenze halten (unterhalb der anaeroben Schwelle), um Crashs (PEM, post-exertionelle Malaise) zu vermeiden. Die Uhr ist nicht für mich selbst, sondern für jemand anderen.

Grenze standardmässig **Ruhepuls + 15 bpm** (Ruhepuls aus dem Garmin-Profil, `UserProfile.getProfile().restingHeartRate`), alternativ eine feste Grenze. Ampel: grün = ok, gelb = ab Grenze −5, rot = über Grenze.

## Projekte

Jedes Projekt ist ein eigener Ordner mit eigenem `monkey.jungle` und `manifest.xml`. In VS Code muss **der Projektordner selbst** geöffnet werden (oder als Multi-Root-Workspace), sonst "Connect IQ project not found".

### `PacingAlarm/` – Geräte-App (watch-app)
- `PacingMonitor.mc`: `Sensor.enableSensorEvents` (~1×/s), vibriert wenn Puls > Grenze länger als `delaySec` (20 s), wiederholt alle `repeatSec` (60 s). Zählt Sekunden über der Grenze.
- `PacingView.mc`: gleiches Design wie das Face (über `shared/PacingDraw`): Uhrzeit oben, grosser Puls in Ampelfarbe, "Grenze X  Ruhe Y", "Seit Start m:ss über" (rot während Alarm), Tages-Zeitachse mit eigener `PacingTimeline` (eigener Storage der App). Während eines Alarms (`alerting`) ist der ganze Ring hell.
- `PacingAlarmApp.mc`: hält Monitor und eine gemeinsame `PacingTimeline` für beide Ansichten. Delegate – nach unten wischen = Grenze +1, nach oben = −1 (schaltet dauerhaft auf feste Grenze), Tippen (`onSelect`) = Verlaufsansicht (`pushView`).
- `PacingHistoryView.mc`: Verlauf wie beim Garmin-Stressdiagramm. Balken je 15 min (Höhe = Maximalpuls, Farbe = Ampel, grauer Stummel = keine Daten), gestrichelte Grenzlinie mit Wert, Skala automatisch (mind. Grenze −25 bis +10, auf 10 gerundet). Tippen wechselt "Heute" (96 Balken, Beschriftung 0/6/12/18/24) ↔ "Letzte 4 Std" (16 Balken mit Lücken, volle Stunden). Überschrift mit Max, unten Minuten über Grenze heute. Zurück = Standardverhalten (popView). Im Simulator geprüft.
- Properties: `mode` (0 fest / 1 Ruhepuls+Aufschlag), `fixedLimit`, `offset`, `delaySec`, `repeatSec`.
- Berechtigungen: `Sensor`, `SensorHistory`, `UserProfile`.
- **Status:** baut fehlerfrei (`-l 3`), Ansicht im Simulator geprüft (ohne Live-Puls). Vibration noch nicht auf der Uhr getestet.

### `shared/` – gemeinsamer Code
Beide `monkey.jungle` haben `base.sourcePath = source;../shared`. Enthält `PacingDraw.mc` (Farben, `ampelColor`, `drawRing`, `drawTwoTone`, `chordWidth`, `drawTimeline`, `timeString`) und `PacingTimeline.mc`.

### `PacingFace/` – Watchface
- `PacingFaceView.mc`: Stil **digital oder analog** (`style` 0/1). Ampel-Ring, Datum, "Puls / Grenze". Always-on/Low-Power-Modus (AMOLED) mit wenig leuchtenden Pixeln. Puls aus `Activity.getActivityInfo().currentHeartRate`, Fallback `ActivityMonitor.getHeartRateHistory`.
- `PacingSettings.mc`: Modul mit `getNum`, `restingHr`, `computeLimit` + **On-Device-Einstellungsmenü** (`Menu2` via `AppBase.getSettingsView`): Stil, Grenzmodus, Aufschlag (10/15/20/25/30 zyklisch), feste Grenze (70–140 in 5er-Schritten zyklisch), Zeitachse an/aus.
- `shared/PacingTimeline.mc`: **Tages-Zeitachse**. 96 Abschnitte à 15 min, je Abschnitt Maximalpuls (0 = keine Daten) + Sekunden über Grenze. `Application.Storage`-Schlüssel `tlDay` (Mitternacht, Unix-s), `tlMax`, `tlLast` (letzter verarbeiteter Zeitpunkt), `tlOver`. `update()` aus `onUpdate`, arbeitet höchstens alle 5 min, füllt Lücken über `SensorHistory.getHeartRateHistory` seit `tlLast` nach (in 3-h-Stücken wegen Watchdog; bei Rückstand gleich beim nächsten `onUpdate` weiter). Reset bei neuem `Time.today()`. Lücken zwischen Samples zählen höchstens 5 min als "über Grenze".
- Zeitachse zeichnen (`PacingDraw.drawTimeline`): Leiste unten, Farben per `ampelColor` mit aktueller Grenze, Zukunft als dünne Linie, Markierungen 6/12/18 Uhr, Jetzt-Strich, Text "Heute X Min über Grenze" mit Kürzungsstufen (`chordWidth`). Im Digitalstil entfällt dann "Puls / Grenze". Im Always-on ausgeblendet.
- Design (`shared/PacingDraw.mc`, Modul für beide Apps): weichere Ampelpalette als Konstanten (`C_GREEN/C_YELLOW/C_RED/C_NODATA` + dunkle `D_*`-Varianten). Ring = breite dunkle Spur + schmaler heller Ring. Zeitachse auf dunkler Spur mit runden Enden, schwarze Fugen bei 6/12/18 Uhr. Zahlen (Puls, Minuten) farbig, Rest grau (`drawTwoTone`). Analog: Zeiger mit schwarzem Rand, Minutenspitze in Ampelfarbe.
- Properties: `style`, `mode`, `fixedLimit`, `offset`, `timeline` (0/1, Standard 1).
- Berechtigungen: `SensorHistory`, `UserProfile`.
- **Status:** baut für `vivoactive5` und `vivoactive5_sim` fehlerfrei, auch mit `-l 3`. Digitalansicht mit Zeitachse im Simulator geprüft (der Simulator liefert Pulsverlauf). Analog mit Zeitachse und Always-on noch nicht im Simulator angesehen; auf der echten Uhr noch nicht getestet.

## Wichtige Plattform-Einschränkungen

- Watchfaces dürfen **nicht vibrieren** → Vibration nur in der App.
- Hintergrunddienste laufen höchstens alle **5 Minuten** → kein Echtzeit-Alarm im Hintergrund.
- Watchface im Low-Power-Modus: Update ~1×/Minute.
- **Per USB installierte Apps** lassen sich **nicht** über die Connect-IQ-Handy-App einstellen → deshalb On-Device-Menü bzw. Standardwerte in `resources/settings/properties.xml`.
- Launcher-Icon Vivoactive 5: **56×56 px**.
- Updates einer installierten App müssen mit **demselben Developer Key** signiert sein.

## Entwicklungsumgebung

- **OS:** CachyOS (Arch-basiert), KDE Plasma auf Wayland, Framework 16.
- **Editor:** Code - OSS mit `code-marketplace` + Erweiterung "Monkey C" (Garmin).
- **SDK:** Connect IQ SDK 9.2.0 unter `~/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2/`, aktueller Pfad in `~/.Garmin/ConnectIQ/current-sdk.cfg`.
- **Developer Key:** `~/.Garmin/ConnectIQ/developer_key` (nicht ins Repo!).
- **Projektpfad:** `~/Code/garmin_me-cfs_pacing/`
- Java funktioniert (Build läuft auf dem Host).

### Bauen (Host)
```bash
SDK=$(cat ~/.Garmin/ConnectIQ/current-sdk.cfg)
cd ~/Code/garmin_me-cfs_pacing
mkdir -p build
"$SDK/bin/monkeyc" -d vivoactive5 -f PacingFace/monkey.jungle  -o build/PacingFace.prg  -y ~/.Garmin/ConnectIQ/developer_key -w
"$SDK/bin/monkeyc" -d vivoactive5 -f PacingAlarm/monkey.jungle -o build/PacingAlarm.prg -y ~/.Garmin/ConnectIQ/developer_key -w
```
Release-Build für die Uhr: zusätzlich `-r` (ohne Debug-Infos, deutlich kleiner). Für den Simulator `-d vivoactive5_sim` (Ausgabe z. B. `build/PacingFace_sim.prg`). Strengere Typprüfung: `-l 3`.

### Simulator (läuft in Distrobox!)
Der Simulator braucht `libwebkit2gtk-4.0.so.37`, die es in Arch nicht mehr gibt. Deshalb läuft er in einer **Distrobox `ciq` (Ubuntu 22.04)** mit `libwebkit2gtk-4.0-37 libjpeg8 libusb-1.0-0 libsm6 libice6 libxext6 libxrender1 libxtst6 libxi6`.
```bash
distrobox enter ciq -- bash -c '"$(cat ~/.Garmin/ConnectIQ/current-sdk.cfg)/bin/simulator"' &
"$SDK/bin/monkeydo" build/PacingFace.prg vivoactive5   # App in laufenden Simulator laden (vom Host)
```
Puls simulieren: Simulator-Menü *Simulation → FIT Data → Simulate Data* bzw. *Activity Data*. Einstellungen: *File → Edit Persistent Storage → Edit Application.Properties data*.

### Auf die Uhr
Uhr per USB (MTP, Dolphin/kio-extras), `.prg` nach `Internal Storage/GARMIN/APPS/` kopieren, auswerfen.

## Mögliche nächste Schritte / Ideen
- PacingFace auf der Uhr testen (Zeitachse: Abstände im echten Pulsverlauf, Watchdog beim ersten Nachfüllen).
- PacingAlarm bauen und im Simulator testen.
- Evtl. On-Device-Menü auch für PacingAlarm (Verzögerung, Wiederholung).
- Evtl. Body Battery / Stress im Watchface anzeigen.
- Git-Repo anlegen, `build/` und Keys in `.gitignore`.

Hinweis: Kein Medizinprodukt; die passende Grenze sollte ärztlich bzw. physiotherapeutisch abgestimmt werden.
