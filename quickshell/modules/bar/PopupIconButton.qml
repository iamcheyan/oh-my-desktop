// PopupIconButton — individual icon button for IconActionRow.
import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: iconBtn
    property string icon: ""
    property string label: ""
    property color accent: SettingsTokens.fg
    property bool enabledState: true
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: 60
    opacity: iconBtn.enabledState ? 1.0 : 0.38

    Rectangle {
        id: iconBtnBg
        anchors.fill: parent
        radius: SettingsTokens.radius
        color: iconBtnMouse.containsMouse && iconBtn.enabledState
            ? SettingsTokens.buttonHover : SettingsTokens.button
        border.width: 1
        border.color: SettingsTokens.buttonBorder

        Behavior on color { ColorAnimation { duration: 100 } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4

            NerdIcon {
                Layout.alignment: Qt.AlignHCenter
                iconSize: 20
                text: iconBtn.icon
                color: iconBtn.accent
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: iconBtn.label
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.small - 1
                font.weight: Font.Medium
                color: SettingsTokens.muted
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    MouseArea {
        id: iconBtnMouse
        anchors.fill: parent
        enabled: iconBtn.enabledState
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: iconBtn.clicked()
    }
}
