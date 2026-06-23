import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell.Services.Notifications

Item {
    id: button
    property string buttonText
    property string urgency
    property bool hovered: hoverArea.containsMouse
    property bool pressed: hoverArea.pressed
    readonly property bool critical: urgency == NotificationUrgency.Critical
    signal clicked()

    implicitWidth: label.implicitWidth + 18
    implicitHeight: 24

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: button.pressed ? (button.critical ? Appearance.tiling.borderCritical : Appearance.tiling.bgActive)
            : button.hovered ? Appearance.tiling.bgHover
            : "transparent"
        border.width: Appearance.tiling.borderWidth
        border.color: button.critical ? Appearance.tiling.borderCritical
            : button.hovered ? Appearance.tiling.borderFocus
            : Appearance.tiling.border
    }

    StyledText {
        id: label
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        font.family: Appearance.font.family.monospace
        font.pixelSize: Appearance.font.pixelSize.small
        text: button.buttonText
        color: button.critical ? Appearance.tiling.error
            : button.pressed ? Appearance.tiling.textBright
            : Appearance.tiling.text
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
