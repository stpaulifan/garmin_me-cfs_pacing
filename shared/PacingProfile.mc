import Toybox.Lang;
import Toybox.UserProfile;

module PacingProfile {
    function restingHr() as Number? {
        var profile = UserProfile.getProfile();
        if (profile has :restingHeartRate) {
            var resting = profile.restingHeartRate;
            if (resting != null && resting > 0) {
                return resting;
            }
        }
        return null;
    }
}