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

    readonly property var weatherIconMap: ({
        "113": "clear_day",
        "116": "partly_cloudy_day",
        "119": "cloud",
        "122": "cloud",
        "143": "foggy",
        "176": "rainy",
        "179": "rainy",
        "182": "rainy",
        "185": "rainy",
        "200": "thunderstorm",
        "227": "cloudy_snowing",
        "230": "snowing_heavy",
        "248": "foggy",
        "260": "foggy",
        "263": "rainy",
        "266": "rainy",
        "281": "rainy",
        "284": "rainy",
        "293": "rainy",
        "296": "rainy",
        "299": "rainy",
        "302": "weather_hail",
        "305": "rainy",
        "308": "weather_hail",
        "311": "rainy",
        "314": "rainy",
        "317": "rainy",
        "320": "cloudy_snowing",
        "323": "cloudy_snowing",
        "326": "cloudy_snowing",
        "329": "snowing_heavy",
        "332": "snowing_heavy",
        "335": "snowing",
        "338": "snowing_heavy",
        "350": "rainy",
        "353": "rainy",
        "356": "rainy",
        "359": "weather_hail",
        "362": "rainy",
        "365": "rainy",
        "368": "cloudy_snowing",
        "371": "snowing",
        "374": "rainy",
        "377": "rainy",
        "386": "thunderstorm",
        "389": "thunderstorm",
        "392": "thunderstorm",
        "395": "snowing"
    })

    
    function getWeatherIcon(code) {
        const key = String(code)
        if (weatherIconMap.hasOwnProperty(key)) {
            return weatherIconMap[key]
        }
    }

    readonly property var weatherCosmicIconMap: ({
        "113": "status/weather-clear-symbolic",
        "116": "status/weather-few-clouds-symbolic",
        "119": "status/weather-overcast-symbolic",
        "122": "status/weather-overcast-symbolic",
        "143": "status/weather-fog-symbolic",
        "176": "status/weather-showers-scattered-symbolic",
        "179": "status/weather-showers-scattered-symbolic",
        "182": "status/weather-showers-scattered-symbolic",
        "185": "status/weather-showers-scattered-symbolic",
        "200": "status/weather-storm-symbolic",
        "227": "status/weather-snow-symbolic",
        "230": "status/weather-snow-symbolic",
        "248": "status/weather-fog-symbolic",
        "260": "status/weather-fog-symbolic",
        "263": "status/weather-showers-scattered-symbolic",
        "266": "status/weather-showers-scattered-symbolic",
        "281": "status/weather-showers-scattered-symbolic",
        "284": "status/weather-showers-scattered-symbolic",
        "293": "status/weather-showers-scattered-symbolic",
        "296": "status/weather-showers-scattered-symbolic",
        "299": "status/weather-showers-symbolic",
        "302": "status/weather-showers-symbolic",
        "305": "status/weather-showers-symbolic",
        "308": "status/weather-showers-symbolic",
        "311": "status/weather-showers-symbolic",
        "314": "status/weather-showers-symbolic",
        "317": "status/weather-showers-symbolic",
        "320": "status/weather-snow-symbolic",
        "323": "status/weather-snow-symbolic",
        "326": "status/weather-snow-symbolic",
        "329": "status/weather-snow-symbolic",
        "332": "status/weather-snow-symbolic",
        "335": "status/weather-snow-symbolic",
        "338": "status/weather-snow-symbolic",
        "350": "status/weather-showers-symbolic",
        "353": "status/weather-showers-scattered-symbolic",
        "356": "status/weather-showers-symbolic",
        "359": "status/weather-showers-symbolic",
        "362": "status/weather-showers-scattered-symbolic",
        "365": "status/weather-showers-symbolic",
        "368": "status/weather-snow-symbolic",
        "371": "status/weather-snow-symbolic",
        "374": "status/weather-showers-symbolic",
        "377": "status/weather-showers-symbolic",
        "386": "status/weather-storm-symbolic",
        "389": "status/weather-storm-symbolic",
        "392": "status/weather-storm-symbolic",
        "395": "status/weather-snow-symbolic"
    })

    function getWeatherCosmicIcon(code) {
        const key = String(code)
        if (weatherCosmicIconMap.hasOwnProperty(key)) {
            return weatherCosmicIconMap[key]
        }
        return "status/weather-overcast-symbolic"
    }
}
