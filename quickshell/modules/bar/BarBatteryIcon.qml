import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

BarNerdIcon {
    id: root

    property real percentage: Battery.percentage
    property bool charging: Battery.isPluggedIn

    // MDI battery glyphs are visually denser than the other top-bar symbols.
    // Keep this exception centralized instead of scaling each battery caller.
    iconSize: Config.options.bar.rightIconSize * 0.78
    opticalBalance: false

    text: {
        const pct = root.percentage;
        if (root.charging) {
            if (pct > 0.9) return NerdIconMap.batteryChargingFull;
            if (pct > 0.8) return NerdIconMap.batteryCharging90;
            if (pct > 0.7) return NerdIconMap.batteryCharging80;
            if (pct > 0.6) return NerdIconMap.batteryCharging70;
            if (pct > 0.5) return NerdIconMap.batteryCharging60;
            if (pct > 0.4) return NerdIconMap.batteryCharging50;
            if (pct > 0.3) return NerdIconMap.batteryCharging40;
            if (pct > 0.2) return NerdIconMap.batteryCharging30;
            if (pct > 0.1) return NerdIconMap.batteryCharging20;
            return NerdIconMap.batteryCharging10;
        }

        if (pct > 0.9) return NerdIconMap.battery90;
        if (pct > 0.8) return NerdIconMap.battery80;
        if (pct > 0.7) return NerdIconMap.battery70;
        if (pct > 0.6) return NerdIconMap.battery60;
        if (pct > 0.5) return NerdIconMap.battery50;
        if (pct > 0.4) return NerdIconMap.battery40;
        if (pct > 0.3) return NerdIconMap.battery30;
        if (pct > 0.2) return NerdIconMap.battery20;
        if (pct > 0.1) return NerdIconMap.battery10;
        return NerdIconMap.batteryAlert;
    }
}
