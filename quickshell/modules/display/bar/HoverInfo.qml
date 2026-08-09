import qs
import qs.services
import qs.modules.common
import qs.modules.bar
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    // Compositor-agnostic screen lookup (Hyprland.monitorFor is Hyprland-only;
    // on labwc it resolves to null). Find the screen containing this item's
    // center in global coordinates, falling back to the primary screen.
    readonly property var _screen: {
        const p = root.mapToGlobal(0, 0);
        const cx = p.x + root.width / 2;
        const cy = p.y + root.height / 2;
        for (const s of Quickshell.screens) {
            if (cx >= s.x && cx < s.x + s.width && cy >= s.y && cy < s.y + s.height)
                return s;
        }
        return Quickshell.screens[0] ?? null;
    }

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
            value: root._screen?.name ?? "Unknown"
        }
        StyledPopupValueRow {
            icon: NerdIconMap.desktop
            label: "Resolution"
            value: root._screen
                ? (root._screen.width + "×" + root._screen.height)
                : "-"
        }
        StyledPopupValueRow {
            icon: NerdIconMap.desktop
            label: "Scale"
            value: root._screen
                ? (root._screen.devicePixelRatio.toFixed(1) + "×")
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
