import Toybox.Application;
import Toybox.Attention;
import Toybox.Lang;
import Toybox.Sensor;
import Toybox.System;
import Toybox.WatchUi;

// Liest den Puls jede Sekunde und vibriert, wenn er zu lange über der Grenze liegt.
class PacingMonitor {
    var hr as Number? = null;
    var limit as Number = 100;
    var restingHr as Number? = null;
    var secondsAbove as Number = 0;   // Summe der Sekunden über der Grenze seit App-Start
    var alerting as Boolean = false;

    private var _delaySec as Number = 20;
    private var _repeatSec as Number = 60;
    private var _lastSettingsRefresh as Number = 0;
    private var _tick as Number = 0;
    private var _aboveSince as Number = -1;
    private var _lastAlert as Number = -1;

    function initialize() {
        loadSettings();
    }

    function loadSettings() as Void {
        var mode = getNum("mode", 1);
        var fixed = getNum("fixedLimit", 100);
        var offset = getNum("offset", 15);
        _delaySec = getNum("delaySec", 20);
        _repeatSec = getNum("repeatSec", 60);

        restingHr = PacingProfile.restingHr();

        var rest = restingHr;
        if (mode == 1 && rest != null) {
            limit = rest + offset;
        } else {
            limit = fixed;
        }
        _lastSettingsRefresh = System.getTimer();
    }

    // Grenze am Gerät anpassen (Wischen). Wechselt dauerhaft auf "feste Grenze".
    function adjust(delta as Number) as Void {
        limit += delta;
        if (limit < 50) { limit = 50; }
        if (limit > 200) { limit = 200; }
        Application.Properties.setValue("mode", 0);
        Application.Properties.setValue("fixedLimit", limit);
        WatchUi.requestUpdate();
    }

    function start() as Void {
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        Sensor.enableSensorEvents(method(:onSensor));
    }

    function stop() as Void {
        Sensor.enableSensorEvents(null);
    }

    // Wird vom System etwa einmal pro Sekunde aufgerufen.
    function onSensor(info as Sensor.Info) as Void {
        _tick++;
        var elapsed = System.getTimer() - _lastSettingsRefresh;
        if (elapsed < 0 || elapsed >= 60000) {
            loadSettings();
        }
        hr = info.heartRate;
        var h = hr;

        if (h != null && h > limit) {
            secondsAbove++;
            if (_aboveSince < 0) {
                _aboveSince = _tick;
            }
            if (_tick - _aboveSince >= _delaySec) {
                alerting = true;
                if (_lastAlert < 0 || _tick - _lastAlert >= _repeatSec) {
                    alarmVibrate();
                    _lastAlert = _tick;
                }
            }
        } else {
            _aboveSince = -1;
            _lastAlert = -1;
            alerting = false;
        }
        WatchUi.requestUpdate();
    }

    private function alarmVibrate() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([
                new Attention.VibeProfile(100, 400),
                new Attention.VibeProfile(0, 200),
                new Attention.VibeProfile(100, 400),
                new Attention.VibeProfile(0, 200),
                new Attention.VibeProfile(100, 400)
            ]);
        }
    }

    private function getNum(key as String, def as Number) as Number {
        var v = Application.Properties.getValue(key);
        if (v instanceof Number) {
            return v;
        }
        return def;
    }
}
