import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class PacingFaceApp extends Application.AppBase {
    private var _view as PacingFaceView?;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var v = new PacingFaceView();
        _view = v;
        return [v];
    }

    // Einstellungsmenü auf der Uhr (funktioniert auch bei per USB installierten Apps)
    function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        return [new PacingSettingsMenu(), new PacingSettingsDelegate()];
    }

    function onSettingsChanged() as Void {
        var v = _view;
        if (v != null) {
            v.loadSettings();
        }
        WatchUi.requestUpdate();
    }
}
