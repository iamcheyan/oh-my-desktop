// XkbPopup.qml — Keyboard layout switcher popup.
import qs
import qs.modules.common
import qs.modules.bar
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

ColumnLayout {
    id: popup
    spacing: 0
    width: parent?.width ?? implicitWidth
    property list<string> layouts: HyprlandXkb.layoutCodes

    PopupHeader {
        Layout.fillWidth: true
        icon: NerdIconMap.keyboard
        title: "Keyboard Layout"
        subtitle: HyprlandXkb.currentLayoutName || "Unknown layout"
        tone: TuiStyle.accent
        showDivider: true
    }

    Repeater {
        model: popup.layouts
        delegate: Rectangle {
            required property string modelData
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: modelData === HyprlandXkb.currentLayoutName ? TuiStyle.panelAlt
                : layoutMouse.containsMouse ? TuiStyle.surfaceHover
                : "transparent"
            radius: TuiStyle.miniRadius

            MouseArea {
                id: layoutMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", `${popup.layouts.indexOf(modelData)}`]);
                    GlobalStates.barPopupType = "";
                }
            }

            StyledText {
                anchors.left: parent.left; anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: modelData
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: modelData === HyprlandXkb.currentLayoutName ? Font.DemiBold : Font.Normal
                color: modelData === HyprlandXkb.currentLayoutName ? TuiStyle.fg : TuiStyle.dim
            }

            NerdIcon {
                anchors.right: parent.right; anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                iconSize: 14
                text: NerdIconMap.check
                color: TuiStyle.accent
                visible: modelData === HyprlandXkb.currentLayoutName
            }
        }
    }
}
