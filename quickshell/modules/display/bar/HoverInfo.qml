import qs
import qs.services
import qs.modules.common
import qs.modules.bar
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

Item {
    readonly property var _monitor: Hyprland.monitorFor(root)

    implicitWidth: Math.min(320, contentLayout.implicitWidth + 16)
    implicitHeight: contentLayout.implicitHeight + 16

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            // Re-evaluate bindings by touching a property
            _dummy = !_dummy;
        }
    }
    property bool _dummy: false

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: 8
        spacing: 2

        StyledPopupValueRow {
            icon: NerdIconMap.desktop
            label: "Monitor"
            value: root._monitor?.name ?? "Unknown"
        }
        StyledPopupValueRow {
            icon: NerdIconMap.desktop
            label: "Resolution"
            value: root._monitor
                ? (root._monitor.width + "×" + root._monitor.height)
                : "-"
        }
        StyledPopupValueRow {
            icon: NerdIconMap.desktop
            label: "Scale"
            value: root._monitor
                ? (root._monitor.scale.toFixed(1) + "×")
                : "-"
        }
        StyledPopupValueRow {
            icon: NerdIconMap.darkMode
            label: "Night mode"
            value: ServiceManager.hyprsunset?.temperatureActive ?? false
                ? "On (" + (ServiceManager.hyprsunset?.colorTemperature ?? "-") + "K)"
                : "Off"
        }
        StyledPopupValueRow {
            icon: NerdIconMap.brightness6
            label: "Brightness"
            value: {
                const b = Brightness.brightnessLevel;
                if (b === undefined || b === null) return "-";
                return Math.round(b * 100) + "%";
            }
        }
    }
}
