import Toybox.Application;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.Time;

// Tages-Zeitachse ähnlich dem Garmin-Stressdiagramm:
// 96 Abschnitte à 15 Minuten (0–24 Uhr), je Abschnitt der maximale Puls
// (0 = keine Daten), dazu die Sekunden über der Grenze.
// Gespeichert in Application.Storage, Reset um Mitternacht.
class PacingTimeline {
    static const SLOTS = 96;
    static const SLOT_SEC = 900;
    private const INTERVAL_SEC = 300;     // höchstens alle 5 Minuten verarbeiten
    private const CHUNK_SEC = 3 * 3600;   // Nachfüllen in Stücken (Watchdog-Limit im onUpdate)
    private const MAX_GAP_SEC = 300;      // längere Lücken zwischen Samples nicht als "über Grenze" zählen

    private var _day as Number = 0;       // Mitternacht des Tages (Unix-Sekunden)
    private var _max as Array<Number>;
    private var _lastTs as Number = 0;    // bis hierher ist der Pulsverlauf verarbeitet
    private var _overSec as Number = 0;
    private var _lastRun as Number = 0;   // nicht gespeichert -> erster Aufruf verarbeitet sofort

    function initialize() {
        _max = emptySlots();
        var day = Application.Storage.getValue("tlDay");
        var max = Application.Storage.getValue("tlMax");
        var last = Application.Storage.getValue("tlLast");
        var over = Application.Storage.getValue("tlOver");
        if (day instanceof Number && max instanceof Array && max.size() == SLOTS) {
            _day = day;
            _max = max as Array<Number>;
            _lastTs = (last instanceof Number) ? last : 0;
            _overSec = (over instanceof Number) ? over : 0;
        }
    }

    // Aus onUpdate aufrufen; arbeitet nur alle 5 Minuten (bzw. bis der Rückstand aufgeholt ist)
    function update(limit as Number, liveHr as Number?) as Void {
        var now = Time.now().value();
        var today = Time.today().value();
        if (today != _day) {
            // Mitternacht: neuer Tag
            _day = today;
            _max = emptySlots();
            _overSec = 0;
            _lastRun = 0;
        }
        if (now - _lastRun < INTERVAL_SEC) {
            return;
        }
        _lastRun = now;

        if (!fillFromHistory(now, limit)) {
            _lastRun = 0;   // Rückstand: beim nächsten onUpdate weitermachen
        }
        // Aktuellen Puls in den laufenden Abschnitt übernehmen (nur für das Maximum)
        if (liveHr != null) {
            addToSlot(now, liveHr);
        }
        save();
    }

    function slotMax(i as Number) as Number {
        return _max[i];
    }

    function overMinutes() as Number {
        return _overSec / 60;
    }

    // Lücken seit dem letzten verarbeiteten Zeitpunkt aus dem Pulsverlauf nachfüllen.
    // Gibt false zurück, wenn noch nicht alles aufgeholt ist.
    private function fillFromHistory(now as Number, limit as Number) as Boolean {
        if (!(Toybox has :SensorHistory) || !(SensorHistory has :getHeartRateHistory)) {
            return true;
        }
        var since = (_lastTs > _day) ? _lastTs : _day;
        if (now <= since) {
            return true;
        }
        var end = since + CHUNK_SEC;
        var done = end >= now;
        if (done) {
            end = now;
        }

        var iter = SensorHistory.getHeartRateHistory({
            :period => new Time.Duration(now - since),
            :order => SensorHistory.ORDER_OLDEST_FIRST
        });
        var prev = since;
        var sample = iter.next();
        while (sample != null) {
            var when = sample.when;
            var hr = sample.data;
            if (when != null) {
                var ts = when.value();
                if (ts > end) {
                    break;
                }
                if (ts > since && hr != null) {
                    var bpm = hr.toNumber();
                    if (bpm > 0) {
                        addToSlot(ts, bpm);
                        if (bpm > limit) {
                            var gap = ts - prev;
                            _overSec += (gap > MAX_GAP_SEC) ? MAX_GAP_SEC : gap;
                        }
                        prev = ts;
                        _lastTs = ts;
                    }
                }
            }
            sample = iter.next();
        }
        // Stück ohne Daten (Uhr nicht getragen) überspringen. Beim letzten Stück
        // nur bis zum neuesten Sample, falls Werte verzögert eingetragen werden.
        if (!done && _lastTs < end) {
            _lastTs = end;
        }
        return done;
    }

    private function addToSlot(ts as Number, bpm as Number) as Void {
        var i = (ts - _day) / SLOT_SEC;
        if (i < 0) {
            return;
        }
        if (i >= SLOTS) {
            i = SLOTS - 1;   // Tag mit 25 Stunden (Zeitumstellung)
        }
        if (bpm > _max[i]) {
            _max[i] = bpm;
        }
    }

    private function save() as Void {
        Application.Storage.setValue("tlDay", _day);
        Application.Storage.setValue("tlMax", _max as Array<Application.Storage.ValueType>);
        Application.Storage.setValue("tlLast", _lastTs);
        Application.Storage.setValue("tlOver", _overSec);
    }

    private function emptySlots() as Array<Number> {
        var a = new Array<Number>[SLOTS];
        for (var i = 0; i < SLOTS; i++) {
            a[i] = 0;
        }
        return a;
    }
}
