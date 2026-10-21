import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.UserProfile;
import Toybox.WatchUi;

// Watchface mit Puls-Ampel: grün = ok, gelb = nahe Grenze, rot = darüber.
// Stil digital oder analog (Einstellung "style": 0 = digital, 1 = analog).
// Watchfaces dürfen nicht vibrieren - dafür ist die Pacing-Alarm-App da.
class PacingFaceView extends WatchUi.WatchFace {
    // Weichere Ampelfarben (AMOLED) und je eine abgedunkelte Variante für Hintergründe
    private const C_GREEN = 0x3DDC84;
    private const C_YELLOW = 0xFFC43D;
    private const C_RED = 0xFF5A5F;
    private const C_NODATA = 0x5A5A5A;
    private const D_GREEN = 0x0E3A24;
    private const D_YELLOW = 0x45340F;
    private const D_RED = 0x4A1719;
    private const D_NODATA = 0x262626;
    private const C_TEXT = 0xB4B4B4;    // Datum, Beschriftungen
    private const C_SUBTLE = 0x6E6E6E;  // Markierungen

    private var _limit as Number = 100;
    private var _analog as Boolean = false;
    private var _sleeping as Boolean = false;
    private var _showTimeline as Boolean = true;
    private var _timeline as PacingTimeline;

    function initialize() {
        WatchFace.initialize();
        _timeline = new PacingTimeline();
        loadSettings();
    }

    function loadSettings() as Void {
        _analog = PacingSettings.getNum("style", 0) == 1;
        _limit = PacingSettings.computeLimit();
        _showTimeline = PacingSettings.getNum("timeline", 1) == 1;
    }

    // Wird auch nach dem Schliessen des Einstellungsmenüs aufgerufen
    function onShow() as Void {
        loadSettings();
    }

    function onEnterSleep() as Void {
        _sleeping = true;
        loadSettings();   // Ruhepuls wird im Tagesverlauf aktualisiert
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _sleeping = false;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        var hr = currentHr();
        if (_showTimeline) {
            _timeline.update(_limit, hr);
        }

        var color = ampelColor(hr);
        if (_analog) {
            drawAnalog(dc, color);
        } else {
            drawDigital(dc, color);
        }
    }

    // ---------- Digital ----------

    private function drawDigital(dc as Dc, color as Number) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var timeText = timeString();

        if (_sleeping) {
            // Always-on (AMOLED): wenig leuchtende Pixel
            dc.setColor(0x9A9A9A, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_NUMBER_MEDIUM, timeText,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy + h / 5, w / 40);
            return;
        }

        drawRing(dc, color);

        // Mit Zeitachse alles etwas nach oben rücken
        var tl = _showTimeline;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, tl ? cy - h / 8 : cy - h / 12, Graphics.FONT_NUMBER_HOT, timeText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(C_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, tl ? h / 5 : h / 4, Graphics.FONT_TINY, dateString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (tl) {
            // Ohne "Puls / Grenze"-Beschriftung, sonst reicht der Platz nicht
            drawHrText(dc, color, cy + h / 14, false);
            drawTimeline(dc, cy + h / 7);
        } else {
            drawHrText(dc, color, cy + h / 6, true);
        }
    }

    // ---------- Analog ----------

    private function drawAnalog(dc as Dc, color as Number) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var r = cx;

        var clock = System.getClockTime();
        var minAngle = clock.min * Math.PI / 30.0;
        var hourAngle = ((clock.hour % 12) * 60 + clock.min) * Math.PI / 360.0;

        if (_sleeping) {
            // Always-on: nur dünne Zeiger und kleiner Ampelpunkt
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            drawHand(dc, cx, cy, hourAngle, r * 0.50, 4);
            drawHand(dc, cx, cy, minAngle, r * 0.78, 3);
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy + h / 4, w / 40);
            return;
        }

        drawRing(dc, color);

        // Stundenmarkierungen: 12/3/6/9 hell, übrige dezent
        for (var i = 0; i < 12; i++) {
            var a = i * Math.PI / 6.0;
            var outer = r * 0.86;
            var inner = (i % 3 == 0) ? r * 0.74 : r * 0.80;
            dc.setColor((i % 3 == 0) ? Graphics.COLOR_WHITE : C_SUBTLE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth((i % 3 == 0) ? 5 : 3);
            dc.drawLine(
                cx + outer * Math.sin(a), cy - outer * Math.cos(a),
                cx + inner * Math.sin(a), cy - inner * Math.cos(a));
        }

        // Datum oben, Puls unten
        dc.setColor(C_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - r * 0.40, Graphics.FONT_XTINY, dateString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (_showTimeline) {
            drawHrText(dc, color, cy + r * 0.24, false);
            drawTimeline(dc, cy + r * 0.38);
        } else {
            drawHrText(dc, color, cy + r * 0.42, false);
        }

        // Zeiger mit schwarzem Rand, damit sie sich von Text und Leiste abheben
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        drawHand(dc, cx, cy, hourAngle, r * 0.52, 16);
        drawHand(dc, cx, cy, minAngle, r * 0.80, 12);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawHand(dc, cx, cy, hourAngle, r * 0.50, 12);
        drawHand(dc, cx, cy, minAngle, r * 0.78, 8);
        // Spitze des Minutenzeigers in Ampelfarbe
        var ms = Math.sin(minAngle);
        var mc = Math.cos(minAngle);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        dc.drawLine(cx + r * 0.62 * ms, cy - r * 0.62 * mc, cx + r * 0.76 * ms, cy - r * 0.76 * mc);

        // Mittelpunkt in Ampelfarbe
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 9);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 5);
    }

    // Zeiger als schmales Trapez vom Mittelpunkt nach aussen
    private function drawHand(dc as Dc, cx as Number, cy as Number, angle as Float or Double,
            length as Float or Double, width as Number) as Void {
        var s = Math.sin(angle);
        var c = Math.cos(angle);
        var half = width / 2.0;
        var tip = half * 0.5;
        var back = length * 0.12;
        dc.fillPolygon([
            [cx - back * s - half * c, cy + back * c - half * s],
            [cx - back * s + half * c, cy + back * c + half * s],
            [cx + length * s + tip * c, cy - length * c + tip * s],
            [cx + length * s - tip * c, cy - length * c - tip * s]
        ]);
    }

    // ---------- Zeitachse ----------

    // Schmale Leiste 0–24 Uhr ab Höhe y, darunter "Heute X Min über Grenze".
    // Farbe je 15-Minuten-Abschnitt nach Maximalpuls, grau = keine Daten.
    private function drawTimeline(dc as Dc, y as Number or Float) as Void {
        var w = dc.getWidth();
        var cx = w / 2;
        var top = y.toNumber();
        var bw = w * 56 / 100;
        var bh = w / 36;
        var x0 = cx - bw / 2;
        var slots = PacingTimeline.SLOTS;

        var clock = System.getClockTime();
        var secOfDay = clock.hour * 3600 + clock.min * 60 + clock.sec;
        var nowSlot = secOfDay / PacingTimeline.SLOT_SEC;

        // Dunkle Spur mit runden Enden als Hintergrund (auch für die Zukunft)
        dc.setColor(D_NODATA, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x0 - 3, top - 3, bw + 6, bh + 6, (bh + 6) / 2);

        for (var i = 0; i <= nowSlot && i < slots; i++) {
            var xa = x0 + i * bw / slots;
            var xb = x0 + (i + 1) * bw / slots;
            var v = _timeline.slotMax(i);
            dc.setColor(ampelColor(v > 0 ? v : null), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(xa, top, xb - xa, bh);
        }

        // Dünne Markierungen bei 6, 12 und 18 Uhr (schwarze Fugen)
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        for (var k = 1; k < 4; k++) {
            dc.fillRectangle(x0 + k * bw / 4, top - 3, 2, bh + 6);
        }

        // Aktuelle Uhrzeit als Strich mit schwarzem Rand
        var xn = x0 + (bw.toLong() * secOfDay / 86400).toNumber();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(xn - 3, top - 8, 7, bh + 16, 3);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(xn - 1, top - 6, 3, bh + 12, 1);

        // Text darunter: Minuten in Farbe (grün bei 0), Rest grau; bei Platzmangel gekürzt
        var font = Graphics.FONT_XTINY;
        var fh = dc.getFontHeight(font);
        var ty = top + bh + 6 + fh / 2;
        var over = _timeline.overMinutes();
        var avail = chordWidth(dc, ty + fh / 2) - 8;
        var pre = "Heute ";
        var post = " Min über Grenze";
        if (textWidth(dc, font, pre, over.toString(), post) > avail) {
            pre = "";
        }
        if (textWidth(dc, font, pre, over.toString(), post) > avail) {
            post = " Min > Grenze";
        }
        drawTwoTone(dc, cx, ty, font, pre, over.toString(), over > 0 ? C_RED : C_GREEN, post);
    }

    private function textWidth(dc as Dc, font as Graphics.FontType, a as String, b as String, c as String) as Number {
        return dc.getTextWidthInPixels(a + b + c, font);
    }

    // Zentrierter Text, mittlerer Teil hervorgehoben, Rest in C_TEXT
    private function drawTwoTone(dc as Dc, cx as Number, y as Number or Float, font as Graphics.FontType,
            pre as String, mid as String, midColor as Number, post as String) as Void {
        var wPre = dc.getTextWidthInPixels(pre, font);
        var wMid = dc.getTextWidthInPixels(mid, font);
        var x = cx - (wPre + wMid + dc.getTextWidthInPixels(post, font)) / 2;
        var just = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(C_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, pre, just);
        dc.setColor(midColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + wPre, y, font, mid, just);
        dc.setColor(C_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + wPre + wMid, y, font, post, just);
    }

    // Nutzbare Breite innerhalb des Ampel-Rings auf Höhe y (rundes Display)
    private function chordWidth(dc as Dc, y as Number) as Number {
        var w = dc.getWidth();
        var r = w / 2 - w / 34 - w / 52;   // Innenkante des Rings
        var dy = y - dc.getHeight() / 2;
        if (dy * dy >= r * r) {
            return 0;
        }
        return (2 * Math.sqrt(r * r - dy * dy)).toNumber();
    }

    // ---------- Gemeinsam ----------

    // Ring mit "Glüheffekt": breite abgedunkelte Spur, darin ein schmaler heller Ring
    private function drawRing(dc as Dc, color as Number) as Void {
        var w = dc.getWidth();
        var cx = w / 2;
        var cy = dc.getHeight() / 2;
        var r = cx - w / 34;
        dc.setColor(dimColor(color), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(w / 26);
        dc.drawCircle(cx, cy, r);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(w / 90 + 2);
        dc.drawCircle(cx, cy, r);
    }

    private function dimColor(color as Number) as Number {
        if (color == C_GREEN) { return D_GREEN; }
        if (color == C_YELLOW) { return D_YELLOW; }
        if (color == C_RED) { return D_RED; }
        return D_NODATA;
    }

    private function drawHrText(dc as Dc, color as Number, y as Number or Float, withLabel as Boolean) as Void {
        var hr = currentHr();
        var hrText = (hr != null) ? hr.toString() : "--";
        // Puls in Ampelfarbe, Grenze grau
        drawTwoTone(dc, dc.getWidth() / 2, y, Graphics.FONT_SMALL, "", hrText, color, " / " + _limit.toString());
        if (withLabel) {
            dc.setColor(C_SUBTLE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(dc.getWidth() / 2, y + dc.getHeight() / 9, Graphics.FONT_XTINY, "Puls / Grenze",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function ampelColor(hr as Number?) as Number {
        if (hr == null) { return C_NODATA; }
        if (hr > _limit) { return C_RED; }
        if (hr > _limit - 5) { return C_YELLOW; }
        return C_GREEN;
    }

    private function timeString() as String {
        var clock = System.getClockTime();
        var hour = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        return hour.format("%02d") + ":" + clock.min.format("%02d");
    }

    private function dateString() as String {
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        return info.day_of_week + " " + info.day.toString() + ". " + info.month;
    }

    private function currentHr() as Number? {
        var act = Activity.getActivityInfo();
        if (act != null && act.currentHeartRate != null) {
            return act.currentHeartRate;
        }
        // Fallback: letzter Wert aus dem Pulsverlauf
        if (ActivityMonitor has :getHeartRateHistory) {
            var sample = ActivityMonitor.getHeartRateHistory(1, true).next();
            if (sample != null && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                return sample.heartRate;
            }
        }
        return null;
    }
}
