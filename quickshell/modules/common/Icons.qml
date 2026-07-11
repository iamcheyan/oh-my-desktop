pragma Singleton

// From https://github.com/caelestia-dots/shell (GPLv3)

import Quickshell
import qs.services

Singleton {
    id: root

    function getBatteryIcon(percentage: int): string {
        if (percentage >= 93) return "battery_android_full";
        if (percentage >= 78) return "battery_android_6";
        if (percentage >= 64) return "battery_android_5";
        if (percentage >= 50) return "battery_android_4";
        if (percentage >= 35) return "battery_android_3";
        if (percentage >= 21) return "battery_android_2";
        if (percentage >= 7) return "battery_android_1";
        return "battery_android_0";
    }

    function getBluetoothDeviceMaterialSymbol(systemIconName: string): string {
        if (systemIconName.includes("headset") || systemIconName.includes("headphones"))
            return "headphones";
        if (systemIconName.includes("audio"))
            return "speaker";
        if (systemIconName.includes("phone"))
            return "smartphone";
        if (systemIconName.includes("mouse"))
            return "mouse";
        if (systemIconName.includes("keyboard"))
            return "keyboard";
        return "bluetooth";
    }

    function getBluetoothDeviceCosmicIcon(systemIconName: string): string {
        if (systemIconName.includes("headset"))
            return "devices/audio-headset-symbolic";
        if (systemIconName.includes("headphones"))
            return "devices/audio-headphones-symbolic";
        if (systemIconName.includes("audio"))
            return "devices/audio-speakers-symbolic";
        if (systemIconName.includes("phone"))
            return "devices/smartphone-symbolic";
        if (systemIconName.includes("mouse"))
            return "devices/input-mouse-symbolic";
        if (systemIconName.includes("keyboard"))
            return "devices/input-keyboard-symbolic";
        return "devices/bluetooth-symbolic";
    }

    function getNetworkMaterialSymbol() {
        if (Network.ethernet) return "lan";
        if (Network.wifiEnabled && Network.wifiStatus === "connected") {
            const strength = Network.active?.strength ?? 0
            if (strength > 83) return "signal_wifi_4_bar";
            if (strength > 67) return "network_wifi";
            if (strength > 50) return "network_wifi_3_bar";
            if (strength > 33) return "network_wifi_2_bar";
            if (strength > 17) return "network_wifi_1_bar";
            return "signal_wifi_0_bar"
        } else {
            if (Network.wifiStatus === "connecting") return "signal_wifi_statusbar_not_connected";
            if (Network.wifiStatus === "disconnected") return "wifi_find";
            if (Network.wifiStatus === "disabled") return "signal_wifi_off";
            return "signal_wifi_bad";
        }
    }

}
