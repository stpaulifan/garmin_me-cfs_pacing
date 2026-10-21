import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Gleiches Design wie PacingFace: Ampel-Ring, grosser Puls in Ampelfarbe,
// Grenze/Ruhepuls, Zeit über Grenze seit Start und Tages-Zeitachse.
// Während eines Alarms leuchtet der ganze Ring.
class PacingView extends WatchUi.View {
    private var _monitor as PacingMonitor;
    private var _timeline as PacingTimeline;

    function initialize(monitor as PacingMonitor) {
        View.initialize();
        _monitor = monitor;
        _timeline = new PacingTimeline();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        var hr = _monitor.hr;
        var limit = _monitor.limit;
        _timeline.update(limit, hr);

        var color = PacingDraw.ampelColor(hr, limit);
        PacingDraw.drawRing(dc, color, _monitor.alerting);

        // Uhrzeit oben
        dc.setColor(PacingDraw.C_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 5, Graphics.FONT_TINY, PacingDraw.timeString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Aktueller Puls gross in Ampelfarbe
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - h / 10, Graphics.FONT_NUMBER_HOT, (hr != null) ? hr.toString() : "--",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Grenze (weiss) und Ruhepuls
        var rest = _monitor.restingHr;
        var y = cy + h / 14;
        PacingDraw.drawTwoTone(dc, cx, y, Graphics.FONT_TINY, "Grenze ", limit.toString(),
            Graphics.COLOR_WHITE, (rest != null) ? "  Ruhe " + rest.toString() : "");

        // Zeit über der Grenze seit App-Start, rot während eines Alarms
        var s = _monitor.secondsAbove;
        var fx = dc.getFontHeight(Graphics.FONT_XTINY);
        y += dc.getFontHeight(Graphics.FONT_TINY) / 2 + fx / 2 + 2;
        PacingDraw.drawTwoTone(dc, cx, y, Graphics.FONT_XTINY, "Seit Start ",
            (s / 60).toString() + ":" + (s % 60).format("%02d"),
            _monitor.alerting ? PacingDraw.C_RED : Graphics.COLOR_WHITE, " über");

        PacingDraw.drawTimeline(dc, y + fx / 2 + 10, _timeline, limit);
    }
}
