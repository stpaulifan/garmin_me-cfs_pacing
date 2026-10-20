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
    private var _limit as Number = 100;
    private var _analog as Boolean = false;
    private var _sleeping as Boolean = false;

    function initialize() {
        WatchFace.initialize();
        loadSettings();
    }

    function loadSettings() as Void {
        _analog = PacingSettings.getNum("style", 0) == 1;
        _limit = PacingSettings.computeLimit();
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

        var color = ampelColor(currentHr());
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
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_NUMBER_MEDIUM, timeText,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy + h / 5, w / 40);
            return;
        }

        drawRing(dc, color);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - h / 12, Graphics.FONT_NUMBER_HOT, timeText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 4, Graphics.FONT_TINY, dateString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        drawHrText(dc, color, cy + h / 6, true);
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

        // Stundenmarkierungen
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 12; i++) {
            var a = i * Math.PI / 6.0;
            var outer = r * 0.86;
            var inner = (i % 3 == 0) ? r * 0.74 : r * 0.80;
            dc.setPenWidth((i % 3 == 0) ? 5 : 3);
            dc.drawLine(
                cx + outer * Math.sin(a), cy - outer * Math.cos(a),
                cx + inner * Math.sin(a), cy - inner * Math.cos(a));
        }

        // Datum oben, Puls unten
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - r * 0.40, Graphics.FONT_XTINY, dateString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        drawHrText(dc, color, cy + r * 0.42, false);

        // Zeiger
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawHand(dc, cx, cy, hourAngle, r * 0.50, 12);
        drawHand(dc, cx, cy, minAngle, r * 0.78, 8);

        // Mittelpunkt in Ampelfarbe
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

    // ---------- Gemeinsam ----------

    private function drawRing(dc as Dc, color as Number) as Void {
        var w = dc.getWidth();
        var cx = w / 2;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(w / 26);
        dc.drawCircle(cx, dc.getHeight() / 2, cx - w / 34);
    }

    private function drawHrText(dc as Dc, color as Number, y as Number or Float, withLabel as Boolean) as Void {
        var hr = currentHr();
        var hrText = (hr != null) ? hr.toString() : "--";
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, y, Graphics.FONT_SMALL, hrText + " / " + _limit.toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (withLabel) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(dc.getWidth() / 2, y + dc.getHeight() / 9, Graphics.FONT_XTINY, "Puls / Grenze",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function ampelColor(hr as Number?) as Number {
        if (hr == null) { return Graphics.COLOR_DK_GRAY; }
        if (hr > _limit) { return Graphics.COLOR_RED; }
        if (hr > _limit - 5) { return Graphics.COLOR_YELLOW; }
        return Graphics.COLOR_GREEN;
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
