import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class PacingView extends WatchUi.View {
    private var _monitor as PacingMonitor;

    function initialize(monitor as PacingMonitor) {
        View.initialize();
        _monitor = monitor;
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var st = _monitor.status();
        var color = Graphics.COLOR_GREEN;
        if (st == 1) { color = Graphics.COLOR_YELLOW; }
        if (st == 2) { color = Graphics.COLOR_RED; }

        // Ampel-Ring
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(w / 22);
        dc.drawCircle(cx, cy, cx - w / 30);

        // Aktueller Puls
        var hr = _monitor.hr;
        var hrText = (hr != null) ? hr.toString() : "--";
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - h / 30, Graphics.FONT_NUMBER_THAI_HOT, hrText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.drawText(cx, h / 5, Graphics.FONT_XTINY, "PACING",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Grenze
        var limitText = "Grenze " + _monitor.limit.toString();
        var rest = _monitor.restingHr;
        if (rest != null) {
            limitText += "  (Ruhe " + rest.toString() + ")";
        }
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + h / 5, Graphics.FONT_TINY, limitText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Zeit über der Grenze
        var s = _monitor.secondsAbove;
        var overText = "Über Grenze " + (s / 60).toString() + ":" + (s % 60).format("%02d");
        dc.setColor(_monitor.alerting ? Graphics.COLOR_RED : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + h / 3, Graphics.FONT_XTINY, overText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
