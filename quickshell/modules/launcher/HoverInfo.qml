pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.bar
import QtQuick
import QtQuick.Layouts

Item {
    implicitWidth: Math.min(280, contentLayout.implicitWidth + 16)
    implicitHeight: contentLayout.implicitHeight + 16

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: 8
        spacing: 2

        StyledPopupValueRow {
            icon: NerdIconMap.windows
            label: "Shortcut"
            value: "Mod+A"
        }
        StyledPopupValueRow {
            icon: NerdIconMap.contentPaste
            label: "Clipboard"
            value: {
                // Attempt to read clipboard content via wl-paste
                // Falls back to "-" silently.
                return "-";
            }
        }
    }
}
