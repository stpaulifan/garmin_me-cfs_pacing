import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class PacingAlarmApp extends Application.AppBase {
    private var _monitor as PacingMonitor;
    private var _timeline as PacingTimeline;   // gemeinsam für Haupt- und Verlaufsansicht

    function initialize() {
        AppBase.initialize();
        _monitor = new PacingMonitor();
        _timeline = new PacingTimeline();
    }

    function onStart(state as Dictionary?) as Void {
        _monitor.start();
    }

    function onStop(state as Dictionary?) as Void {
        _monitor.stop();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new PacingView(_monitor, _timeline), new PacingDelegate(_monitor, _timeline)];
    }

    function onSettingsChanged() as Void {
        _monitor.loadSettings();
        WatchUi.requestUpdate();
    }
}

// Wischen nach unten = Grenze +1, nach oben = Grenze -1.
// Tippen = Verlaufsansicht. Zurück-Taste beendet.
class PacingDelegate extends WatchUi.BehaviorDelegate {
    private var _monitor as PacingMonitor;
    private var _timeline as PacingTimeline;

    function initialize(monitor as PacingMonitor, timeline as PacingTimeline) {
        BehaviorDelegate.initialize();
        _monitor = monitor;
        _timeline = timeline;
    }

    function onSelect() as Boolean {
        var view = new PacingHistoryView(_monitor, _timeline);
        WatchUi.pushView(view, new PacingHistoryDelegate(view), WatchUi.SLIDE_LEFT);
        return true;
    }

    function onPreviousPage() as Boolean {
        _monitor.adjust(1);
        return true;
    }

    function onNextPage() as Boolean {
        _monitor.adjust(-1);
        return true;
    }
}
