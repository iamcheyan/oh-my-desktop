import QtQuick

QtObject {
    required property var lastIpcObject
    readonly property string ssid: lastIpcObject.ssid
    readonly property string bssid: lastIpcObject.bssid
    readonly property int strength: lastIpcObject.strength
    readonly property int frequency: lastIpcObject.frequency
    readonly property bool active: lastIpcObject.active
    readonly property string security: lastIpcObject.security
    // Open networks often report "" or "--"; treat those as open.
    readonly property bool isSecure: {
        const s = (security || "").trim().toLowerCase()
        return s.length > 0 && s !== "--" && s !== "none" && s !== "open" && s !== "owe"
    }

    property bool askingPassword: false
}
