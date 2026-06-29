import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    StyledPopupContent {
        // 1. Battery capacity and state (Charging / Discharging)
        StyledPopupValueRow {
            icon: Battery.isCharging ? "status/plugged-into-power-symbolic" : "devices/battery-symbolic"
            label: Translation.tr("Battery Level:")
            value: {
                const pct = Math.round(Battery.percentage * 100);
                const stateStr = Battery.isCharging
                    ? Translation.tr(" (Charging)")
                    : (Battery.isPluggedIn ? Translation.tr(" (Plugged in)") : Translation.tr(" (Discharging)"));
                return `${pct}%${stateStr}`;
            }
        }

        // 2. Remaining Time to Empty / Full
        StyledPopupValueRow {
            visible: {
                let timeValue = Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty;
                let power = Battery.energyRate;
                return Battery.available && !(Battery.chargeState == 4 || timeValue <= 0 || power <= 0.01);
            }
            icon: "actions/appointment-new-symbolic"
            label: Battery.isCharging ? Translation.tr("Time to Full:") : Translation.tr("Time to Empty:")
            value: {
                function formatTime(seconds) {
                    var h = Math.floor(seconds / 3600);
                    var m = Math.floor((seconds % 3600) / 60);
                    if (h > 0)
                        return `${h}h ${m}m`;
                    else
                        return `${m}m`;
                }
                return Battery.isCharging ? formatTime(Battery.timeToFull) : formatTime(Battery.timeToEmpty);
            }
        }

        // 3. Power consumption rate (Watts)
        StyledPopupValueRow {
            visible: Battery.available && Battery.chargeState != 4 && Battery.energyRate > 0.01
            icon: "status/plugged-into-power-symbolic"
            label: Translation.tr("Power Draw:")
            value: `${Battery.energyRate.toFixed(1)}W`
        }

        // 4. Power Profile Mode
        StyledPopupValueRow {
            visible: PowerProfiles.available
            icon: "categories/preferences-system-symbolic"
            label: Translation.tr("Power Profile:")
            value: {
                const profile = PowerProfiles.currentProfile;
                if (profile === "performance") return Translation.tr("Performance");
                if (profile === "balanced") return Translation.tr("Balanced");
                if (profile === "power-saver") return Translation.tr("Power Saver");
                return profile;
            }
        }
    }
}
