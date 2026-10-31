import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// Verlaufsansicht ähnlich dem Garmin-Stressdiagramm: ein Balken je 15 Minuten,
// Höhe = Maximalpuls, Farbe = Ampel, gestrichelte Linie = Grenze.
// Tippen wechselt zwischen Tages-, Vier-Stunden- und Wochenansicht.
class PacingHistoryView extends WatchUi.View {
    private var _monitor as PacingMonitor;
    private var _timeline as PacingTimeline;
    private var _range as Number = 0;

    function initialize(monitor as PacingMonitor, timeline as PacingTimeline) {
        View.initialize();
        _monitor = monitor;
        _timeline = timeline;
    }

    function toggleRange() as Void {
        _range = (_range + 1) % 3;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var limit = _monitor.limit;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        _timeline.update(limit, _monitor.hr);
        PacingDraw.drawRing(dc, PacingDraw.ampelColor(_monitor.hr, limit), _monitor.alerting);

        if (_range == 2) {
            drawWeek(dc);
            return;
        }

        // Angezeigter Bereich in Abschnitten
        var clock = System.getClockTime();
        var secOfDay = clock.hour * 3600 + clock.min * 60 + clock.sec;
        var nowSlot = secOfDay / PacingTimeline.SLOT_SEC;
        var first = 0;
        var count = PacingTimeline.SLOTS;
        if (_range == 1) {
            count = 16;
            first = nowSlot - count + 1;
        }

        // Skala aus den Daten, Grenze immer sichtbar
        var maxHr = 0;
        var minHr = 999;
        for (var i = first; i <= nowSlot && i < first + count; i++) {
            if (i >= 0) {
                var v = _timeline.slotMax(i);
                if (v > 0) {
                    if (v > maxHr) { maxHr = v; }
                    if (v < minHr) { minHr = v; }
                }
            }
        }
        var hi = (maxHr > limit + 10) ? maxHr : limit + 10;
        var lo = (minHr < limit - 25) ? minHr : limit - 25;
        hi = (hi + 9) / 10 * 10;
        lo = lo / 10 * 10;
        if (lo < 0) { lo = 0; }

        // Diagrammfläche
        var x0 = w * 19 / 100;
        var cw = w * 60 / 100;
        var top = h * 30 / 100;
        var bottom = h * 68 / 100;
        var ch = bottom - top;

        // Überschrift mit Höchstwert
        PacingDraw.drawTwoTone(dc, cx, h * 19 / 100, Graphics.FONT_XTINY,
            (_range == 1) ? "Letzte 4 Std · Max " : "Heute · Max ",
            (maxHr > 0) ? maxHr.toString() : "--",
            PacingDraw.ampelColor(maxHr > 0 ? maxHr : null, limit), "");

        // Hilfslinien: 6/12/18 Uhr bzw. volle Stunden
        dc.setColor(PacingDraw.D_NODATA, Graphics.COLOR_TRANSPARENT);
        for (var i = first + 1; i < first + count; i++) {
            if (i >= 0 && i % ((_range == 1) ? 4 : 24) == 0) {
                var xg = x0 + (i - first) * cw / count;
                dc.fillRectangle(xg, top, 1, ch);
            }
        }

        // Balken
        for (var i = first; i <= nowSlot && i < first + count; i++) {
            if (i < 0) { continue; }
            var xa = x0 + (i - first) * cw / count;
            var xb = x0 + (i - first + 1) * cw / count;
            var gap = (_range == 1) ? 3 : 0;
            var v = _timeline.slotMax(i);
            if (v > 0) {
                var bh = (v - lo) * ch / (hi - lo);
                if (bh < 2) { bh = 2; }
                dc.setColor(PacingDraw.ampelColor(v, limit), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(xa, bottom - bh, xb - xa - gap, bh);
            } else {
                // keine Daten: kleiner grauer Stummel
                dc.setColor(PacingDraw.C_NODATA, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(xa, bottom - 2, xb - xa - gap, 2);
            }
        }

        // Grundlinie
        dc.setColor(PacingDraw.C_SUBTLE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x0, bottom, cw, 1);

        // Grenze als gestrichelte Linie mit Wert rechts daneben
        var yl = bottom - (limit - lo) * ch / (hi - lo);
        dc.setColor(PacingDraw.C_TEXT, Graphics.COLOR_TRANSPARENT);
        for (var x = x0; x < x0 + cw; x += 8) {
            dc.fillRectangle(x, yl, 4, 1);
        }
        dc.drawText(x0 + cw + 4, yl, Graphics.FONT_XTINY, limit.toString(),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Zeitbeschriftung unter der Grundlinie
        var ly = bottom + dc.getFontHeight(Graphics.FONT_XTINY) / 2 + 4;
        dc.setColor(PacingDraw.C_SUBTLE, Graphics.COLOR_TRANSPARENT);
        if (_range == 1) {
            for (var i = first; i <= first + count; i++) {
                if (i >= 0 && i % 4 == 0) {
                    dc.drawText(x0 + (i - first) * cw / count, ly, Graphics.FONT_XTINY, (i / 4).toString(),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                }
            }
        } else {
            for (var k = 0; k <= 4; k++) {
                dc.drawText(x0 + k * cw / 4, ly, Graphics.FONT_XTINY, (k * 6).toString(),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        // Minuten über der Grenze heute
        var font = Graphics.FONT_XTINY;
        var fh = dc.getFontHeight(font);
        var ty = ly + fh + 2;
        var over = _timeline.overMinutes();
        var post = " Min über Grenze";
        if (dc.getTextWidthInPixels(over.toString() + post, font) > PacingDraw.chordWidth(dc, ty + fh / 2) - 8) {
            post = " Min > Grenze";
        }
        PacingDraw.drawTwoTone(dc, cx, ty, font, "", over.toString(),
            over > 0 ? PacingDraw.C_RED : PacingDraw.C_GREEN, post);
    }

    private function drawWeek(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var x0 = w * 10 / 100;
        var cw = w * 80 / 100;
        var top = h * 31 / 100;
        var bottom = h * 68 / 100;
        var ch = bottom - top;
        var maxMinutes = 0;
        var totalMinutes = 0;
        var totalDays = 0;

        for (var i = 6; i >= 0; i--) {
            var minutes = _timeline.weekMinutes(i);
            if (minutes >= 0) {
                if (minutes > maxMinutes) { maxMinutes = minutes; }
                totalMinutes += minutes;
                totalDays++;
            }
        }
        if (maxMinutes < 10) { maxMinutes = 10; }
        var scaleMax = ((maxMinutes + 4) / 5) * 5;

        PacingDraw.drawTwoTone(dc, cx, h * 19 / 100, Graphics.FONT_XTINY,
            "7 Tage · Min über Grenze", "", Graphics.COLOR_WHITE, "");

        dc.setColor(PacingDraw.D_NODATA, Graphics.COLOR_TRANSPARENT);
        for (var guide = 1; guide <= 2; guide++) {
            var gy = bottom - guide * ch / 3;
            dc.fillRectangle(x0, gy, cw, 1);
        }
        dc.setColor(PacingDraw.C_SUBTLE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x0, bottom, cw, 1);

        var labelY = bottom + dc.getFontHeight(Graphics.FONT_XTINY) / 2 + 3;
        for (var dayIndex = 0; dayIndex < 7; dayIndex++) {
            var daysAgo = 6 - dayIndex;
            var minutes = _timeline.weekMinutes(daysAgo);
            var barWidth = cw / 7 - 3;
            var x = x0 + dayIndex * cw / 7 + 1;
            if (minutes >= 0) {
                var barHeight = minutes * ch / scaleMax;
                if (barHeight < 2) { barHeight = 2; }
                dc.setColor(minutes > 0 ? PacingDraw.C_RED : PacingDraw.C_GREEN, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, bottom - barHeight, barWidth, barHeight);
                dc.setColor(PacingDraw.C_TEXT, Graphics.COLOR_TRANSPARENT);
                dc.drawText(x + barWidth / 2, bottom - barHeight - 5, Graphics.FONT_XTINY,
                    minutes.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            } else {
                dc.setColor(PacingDraw.C_NODATA, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, bottom - 2, barWidth, 2);
            }
            dc.setColor(PacingDraw.C_SUBTLE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + barWidth / 2, labelY, Graphics.FONT_XTINY,
                _timeline.weekDateLabel(daysAgo), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        var footer = (totalDays > 0) ? totalMinutes.toString() + " Min gesamt" : "Keine Daten";
        dc.setColor(totalMinutes > 0 ? PacingDraw.C_RED : PacingDraw.C_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 86 / 100, Graphics.FONT_XTINY, footer,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

// Tippen = Zeitraum wechseln, Zurück = zur Hauptansicht (Standardverhalten)
class PacingHistoryDelegate extends WatchUi.BehaviorDelegate {
    private var _view as PacingHistoryView;

    function initialize(view as PacingHistoryView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        _view.toggleRange();
        return true;
    }
}
