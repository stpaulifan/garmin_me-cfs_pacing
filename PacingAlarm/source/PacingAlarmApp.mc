import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class PacingAlarmApp extends Application.AppBase {
    private var _monitor as PacingMonitor;

    function initialize() {
        AppBase.initialize();
        _monitor = new PacingMonitor();
    }

    function onStart(state as Dictionary?) as Void {
        _monitor.start();
    }

    function onStop(state as Dictionary?) as Void {
        _monitor.stop();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new PacingView(_monitor), new PacingDelegate(_monitor)];
    }

    function onSettingsChanged() as Void {
        _monitor.loadSettings();
        WatchUi.requestUpdate();
    }
}

// Wischen nach unten = Grenze +1, nach oben = Grenze -1. Zurück-Taste beendet.
class PacingDelegate extends WatchUi.BehaviorDelegate {
    private var _monitor as PacingMonitor;

    function initialize(monitor as PacingMonitor) {
        BehaviorDelegate.initialize();
        _monitor = monitor;
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
