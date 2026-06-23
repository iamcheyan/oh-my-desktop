pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.modules.ii.bar.weather
import qs.modules.ii.bar.modules

QtObject {
    id: registry

    component ModuleEntry: QtObject {
        property string name
        property Component component
        property string description
    }

    readonly property var entries: ({
        "weather": { component: Qt.createComponent("weather/WeatherBar.qml"), description: qsTr("Weather") },
        "systray": { component: Qt.createComponent("SysTray.qml"), description: qsTr("System tray") },
        "media": { component: Qt.createComponent("Media.qml"), description: qsTr("Media controls") },
        "battery": { component: Qt.createComponent("BatteryIndicator.qml"), description: qsTr("Battery") },
        "sidebar": { component: Qt.createComponent("SidebarIndicators.qml"), description: qsTr("Sidebar indicators (volume/mic/keyboard/notifications/power)") },
        "spacer": { component: Qt.createComponent("SpacerItem.qml"), description: qsTr("Flexible spacer") },

        "util:bluetooth": { component: Qt.createComponent("modules/BluetoothButton.qml"), description: qsTr("Bluetooth dialog") },
        "util:wifi": { component: Qt.createComponent("modules/WifiButton.qml"), description: qsTr("Wi-Fi dialog") },
        "util:clipboard": { component: Qt.createComponent("modules/ClipboardButton.qml"), description: qsTr("Clipboard dialog") },
        "util:screenshot": { component: Qt.createComponent("modules/ScreenshotButton.qml"), description: qsTr("Screenshot tool") },
        "util:colorpicker": { component: Qt.createComponent("modules/ColorPickerButton.qml"), description: qsTr("Color picker") },
        "util:mic": { component: Qt.createComponent("modules/MicButton.qml"), description: qsTr("Microphone mute toggle") },
        "util:nightlight": { component: Qt.createComponent("modules/NightLightButton.qml"), description: qsTr("Night Light toggle") },
        "util:idle": { component: Qt.createComponent("modules/IdleButton.qml"), description: qsTr("Idle inhibitor toggle") },
        "util:audio": { component: Qt.createComponent("modules/AudioButton.qml"), description: qsTr("Audio output dialog") }
    })

    function componentForName(name) {
        const entry = registry.entries[name];
        return entry ? entry.component : null;
    }

    function descriptionForName(name) {
        const entry = registry.entries[name];
        return entry ? entry.description : name;
    }

    function allNames() {
        return Object.keys(registry.entries);
    }
}