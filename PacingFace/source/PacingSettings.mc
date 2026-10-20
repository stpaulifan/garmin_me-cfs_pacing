import Toybox.Application;
import Toybox.Lang;
import Toybox.UserProfile;
import Toybox.WatchUi;

// Gemeinsame Hilfsfunktionen für die Einstellungen
module PacingSettings {
    const OFFSETS = [10, 15, 20, 25, 30] as Array<Number>;
    const FIXED_MIN = 70;
    const FIXED_MAX = 140;
    const FIXED_STEP = 5;

    function getNum(key as String, def as Number) as Number {
        var v = Application.Properties.getValue(key);
        if (v instanceof Number) {
            return v;
        }
        return def;
    }

    function restingHr() as Number? {
        var profile = UserProfile.getProfile();
        if (profile has :restingHeartRate) {
            var r = profile.restingHeartRate;
            if (r != null && r > 0) {
                return r;
            }
        }
        return null;
    }

    function computeLimit() as Number {
        var fixed = getNum("fixedLimit", 100);
        if (getNum("mode", 1) == 1) {
            var r = restingHr();
            if (r != null) {
                return r + getNum("offset", 15);
            }
        }
        return fixed;
    }
}

// Einstellungsmenü direkt auf der Uhr
// (Zifferblatt lange drücken -> Pacing Face -> Anpassen / Einstellungen)
class PacingSettingsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title => "Pacing"});

        addItem(new WatchUi.ToggleMenuItem("Stil",
            {:enabled => "Analog", :disabled => "Digital"},
            :style, PacingSettings.getNum("style", 0) == 1, null));

        addItem(new WatchUi.ToggleMenuItem("Grenze",
            {:enabled => "Ruhepuls + Aufschlag", :disabled => "Feste Grenze"},
            :mode, PacingSettings.getNum("mode", 1) == 1, null));

        addItem(new WatchUi.MenuItem("Aufschlag",
            "+" + PacingSettings.getNum("offset", 15).toString() + " bpm", :offset, null));

        addItem(new WatchUi.MenuItem("Feste Grenze",
            PacingSettings.getNum("fixedLimit", 100).toString() + " bpm", :fixedLimit, null));
    }
}

class PacingSettingsDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();

        if (id == :style || id == :mode) {
            var on = (item as WatchUi.ToggleMenuItem).isEnabled();
            Application.Properties.setValue(id == :style ? "style" : "mode", on ? 1 : 0);

        } else if (id == :offset) {
            // Zyklisch durch 10, 15, 20, 25, 30
            var cur = PacingSettings.getNum("offset", 15);
            var list = PacingSettings.OFFSETS;
            var next = list[0];
            for (var i = 0; i < list.size(); i++) {
                if (list[i] > cur) {
                    next = list[i];
                    break;
                }
            }
            Application.Properties.setValue("offset", next);
            item.setSubLabel("+" + next.toString() + " bpm");

        } else if (id == :fixedLimit) {
            // Zyklisch von 70 bis 140 in 5er-Schritten
            var cur = PacingSettings.getNum("fixedLimit", 100) + PacingSettings.FIXED_STEP;
            if (cur > PacingSettings.FIXED_MAX) {
                cur = PacingSettings.FIXED_MIN;
            }
            Application.Properties.setValue("fixedLimit", cur);
            item.setSubLabel(cur.toString() + " bpm");
        }
        WatchUi.requestUpdate();
    }
}
