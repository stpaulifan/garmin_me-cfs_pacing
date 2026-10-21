import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

// Gemeinsames Design für PacingFace und PacingAlarm:
// Ampelfarben, Ring, zweifarbiger Text und Tages-Zeitachse.
module PacingDraw {
    // Weichere Ampelfarben (AMOLED) und je eine abgedunkelte Variante für Hintergründe
    const C_GREEN = 0x3DDC84;
    const C_YELLOW = 0xFFC43D;
    const C_RED = 0xFF5A5F;
    const C_NODATA = 0x5A5A5A;
    const D_GREEN = 0x0E3A24;
    const D_YELLOW = 0x45340F;
    const D_RED = 0x4A1719;
    const D_NODATA = 0x262626;
    const C_TEXT = 0xB4B4B4;    // Datum, Beschriftungen
    const C_SUBTLE = 0x6E6E6E;  // Markierungen

    // grün < Grenze−5, gelb bis Grenze, rot darüber, grau = keine Daten
    function ampelColor(hr as Number?, limit as Number) as Number {
        if (hr == null) { return C_NODATA; }
        if (hr > limit) { return C_RED; }
        if (hr > limit - 5) { return C_YELLOW; }
        return C_GREEN;
    }

    function dimColor(color as Number) as Number {
        if (color == C_GREEN) { return D_GREEN; }
        if (color == C_YELLOW) { return D_YELLOW; }
        if (color == C_RED) { return D_RED; }
        return D_NODATA;
    }

    // Ring mit "Glüheffekt": breite abgedunkelte Spur, darin ein schmaler heller Ring.
    // strong = ganzer Ring hell (z. B. während eines Alarms)
    function drawRing(dc as Dc, color as Number, strong as Boolean) as Void {
        var w = dc.getWidth();
        var cx = w / 2;
        var cy = dc.getHeight() / 2;
        var r = cx - w / 34;
        dc.setColor(strong ? color : dimColor(color), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(w / 26);
        dc.drawCircle(cx, cy, r);
        if (!strong) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(w / 90 + 2);
            dc.drawCircle(cx, cy, r);
        }
    }

    // Zentrierter Text, mittlerer Teil hervorgehoben, Rest in C_TEXT
    function drawTwoTone(dc as Dc, cx as Number, y as Number or Float, font as Graphics.FontType,
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
    function chordWidth(dc as Dc, y as Number) as Number {
        var w = dc.getWidth();
        var r = w / 2 - w / 34 - w / 52;   // Innenkante des Rings
        var dy = y - dc.getHeight() / 2;
        if (dy * dy >= r * r) {
            return 0;
        }
        return (2 * Math.sqrt(r * r - dy * dy)).toNumber();
    }

    // Schmale Leiste 0–24 Uhr ab Höhe y, darunter "Heute X Min über Grenze".
    // Farbe je 15-Minuten-Abschnitt nach Maximalpuls, grau = keine Daten.
    function drawTimeline(dc as Dc, y as Number or Float, timeline as PacingTimeline, limit as Number) as Void {
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
            var v = timeline.slotMax(i);
            dc.setColor(ampelColor(v > 0 ? v : null, limit), Graphics.COLOR_TRANSPARENT);
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
        var over = timeline.overMinutes().toString();
        var avail = chordWidth(dc, ty + fh / 2) - 8;
        var pre = "Heute ";
        var post = " Min über Grenze";
        if (dc.getTextWidthInPixels(pre + over + post, font) > avail) {
            pre = "";
        }
        if (dc.getTextWidthInPixels(pre + over + post, font) > avail) {
            post = " Min > Grenze";
        }
        drawTwoTone(dc, cx, ty, font, pre, over, timeline.overMinutes() > 0 ? C_RED : C_GREEN, post);
    }

    // Uhrzeit "HH:MM" unter Beachtung der 12/24-Stunden-Einstellung
    function timeString() as String {
        var clock = System.getClockTime();
        var hour = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        return hour.format("%02d") + ":" + clock.min.format("%02d");
    }
}
