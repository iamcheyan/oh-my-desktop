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
        radius: TuiStyle.miniRadius
        color: button.pressed ? (button.critical ? TuiStyle.dangerPanel : TuiStyle.surfacePressed)
            : button.hovered ? TuiStyle.surfaceHover
            : "transparent"
        border.width: TuiStyle.borderWidth
        border.color: button.critical ? TuiStyle.danger
            : button.hovered ? TuiStyle.shellBorder
            : TuiStyle.line
    }

    StyledText {
        id: label
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        font.family: Appearance.font.family.monospace
        font.pixelSize: Appearance.font.pixelSize.small
        text: button.buttonText
        color: button.critical ? TuiStyle.danger
            : button.pressed ? TuiStyle.fg
            : TuiStyle.dim
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
