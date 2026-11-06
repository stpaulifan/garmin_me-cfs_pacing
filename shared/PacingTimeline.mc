import Toybox.Application;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Tages-Zeitachse ähnlich dem Garmin-Stressdiagramm:
// 96 Abschnitte à 15 Minuten (0–24 Uhr), je Abschnitt der maximale Puls
// (0 = keine Daten), dazu die Sekunden über der Grenze.
// Gespeichert in Application.Storage, Reset um Mitternacht.
class PacingTimeline {
    static const SLOTS = 96;
    static const SLOT_SEC = 900;
    static const WEEK_SLOTS = 14;
    private const INTERVAL_SEC = 300;     // höchstens alle 5 Minuten verarbeiten
    private const CHUNK_SEC = 3 * 3600;   // Nachfüllen in Stücken (Watchdog-Limit im onUpdate)
    private const MAX_GAP_SEC = 300;      // längere Lücken zwischen Samples nicht als "über Grenze" zählen

    private var _day as Number = 0;       // Mitternacht des Tages (Unix-Sekunden)
    private var _max as Array<Number>;
    private var _lastTs as Number = 0;    // bis hierher ist der Pulsverlauf verarbeitet
    private var _overSec as Number = 0;
    private var _lastRun as Number = 0;   // nicht gespeichert -> erster Aufruf verarbeitet sofort
    private var _weekDateKeys as Array<Number>;   // Datum als JJJJMMTT, 0 = leer
    private var _weekOverSec as Array<Number>;

    function initialize() {
        _max = emptySlots();
        _weekDateKeys = emptyWeekDates();
        _weekOverSec = emptyWeekValues();
        var day = Application.Storage.getValue("tlDay");
        var max = Application.Storage.getValue("tlMax");
        var last = Application.Storage.getValue("tlLast");
        var over = Application.Storage.getValue("tlOver");
        var weekDates = Application.Storage.getValue("tlWeekKeys");
        var weekOver = Application.Storage.getValue("tlWeekOver");
        if (day instanceof Number && max instanceof Array && max.size() == SLOTS) {
            _day = day;
            _max = max as Array<Number>;
            _lastTs = (last instanceof Number) ? last : 0;
            _overSec = (over instanceof Number) ? over : 0;
        }
        if (weekDates instanceof Array && weekDates.size() == WEEK_SLOTS &&
                weekOver instanceof Array && weekOver.size() == WEEK_SLOTS) {
            _weekDateKeys = weekDates as Array<Number>;
            _weekOverSec = weekOver as Array<Number>;
        }
    }

    // Aus onUpdate aufrufen; arbeitet nur alle 5 Minuten (bzw. bis der Rückstand aufgeholt ist)
    function update(limit as Number, liveHr as Number?) as Void {
        var now = Time.now().value();
        var today = Time.today().value();
        if (today != _day) {
            // Mitternacht: alten Tag erst bis zu seinem Ende aus dem Pulsverlauf
            // vervollständigen (in Stücken, Watchdog), dann archivieren
            if (_day > 0 && hasDayData()) {
                var dayEnd = _day + 86400;
                if (dayEnd > today) {
                    dayEnd = today;   // Tag mit 23 Stunden (Zeitumstellung)
                }
                if (!fillFromHistory(dayEnd, limit)) {
                    save();
                    return;   // beim nächsten onUpdate weiter
                }
            }
            archiveDay();
            _day = today;
            _max = emptySlots();
            _lastTs = today;
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

    function weekMinutes(daysAgo as Number) as Number {
        if (daysAgo == 0) {
            return hasDayData() ? _overSec / 60 : -1;
        }
        var key = dateKey(dayMoment(daysAgo));
        for (var i = 0; i < WEEK_SLOTS; i++) {
            if (_weekDateKeys[i] == key) {
                return _weekOverSec[i] / 60;
            }
        }
        return -1;
    }

    function weekDateLabel(daysAgo as Number) as String {
        var info = Gregorian.info(new Time.Moment(dayMoment(daysAgo)), Time.FORMAT_SHORT);
        return info.day.toString();
    }

    // Mittag des Tages vor daysAgo Tagen – Mittag, damit Zeitumstellungen
    // (23/25-Stunden-Tage) nicht auf den Nachbartag verschieben
    private function dayMoment(daysAgo as Number) as Number {
        return Time.today().value() + 12 * 3600 - daysAgo * 86400;
    }

    private function archiveDay() as Void {
        if (!hasDayData()) {
            return;
        }
        var key = dateKey(_day);
        var index = -1;
        for (var i = 0; i < WEEK_SLOTS; i++) {
            if (_weekDateKeys[i] == key) {
                index = i;
                break;
            }
            if (index < 0 && _weekDateKeys[i] == 0) {
                index = i;
            }
        }
        if (index < 0) {
            for (var i = 1; i < WEEK_SLOTS; i++) {
                _weekDateKeys[i - 1] = _weekDateKeys[i];
                _weekOverSec[i - 1] = _weekOverSec[i];
            }
            index = WEEK_SLOTS - 1;
        }
        _weekDateKeys[index] = key;
        _weekOverSec[index] = _overSec;
    }

    private function hasDayData() as Boolean {
        if (_lastTs > _day) {
            return true;
        }
        for (var i = 0; i < SLOTS; i++) {
            if (_max[i] > 0) {
                return true;
            }
        }
        return false;
    }

    // Zahl statt String: == vergleicht bei Strings nicht zuverlässig den Inhalt
    private function dateKey(timestamp as Number) as Number {
        var info = Gregorian.info(new Time.Moment(timestamp), Time.FORMAT_SHORT);
        return info.year * 10000 + (info.month as Number) * 100 + info.day;
    }

    // Lücken seit dem letzten verarbeiteten Zeitpunkt bis "now" aus dem Pulsverlauf
    // nachfüllen ("now" kann beim Tageswechsel das Ende des alten Tages sein).
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
            :period => new Time.Duration(Time.now().value() - since),
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
        Application.Storage.setValue("tlWeekKeys", _weekDateKeys as Array<Application.Storage.ValueType>);
        Application.Storage.setValue("tlWeekOver", _weekOverSec as Array<Application.Storage.ValueType>);
    }

    private function emptySlots() as Array<Number> {
        var a = new Array<Number>[SLOTS];
        for (var i = 0; i < SLOTS; i++) {
            a[i] = 0;
        }
        return a;
    }

    private function emptyWeekDates() as Array<Number> {
        var a = new Array<Number>[WEEK_SLOTS];
        for (var i = 0; i < WEEK_SLOTS; i++) {
            a[i] = 0;
        }
        return a;
    }

    private function emptyWeekValues() as Array<Number> {
        var a = new Array<Number>[WEEK_SLOTS];
        for (var i = 0; i < WEEK_SLOTS; i++) {
            a[i] = 0;
        }
        return a;
    }
}
