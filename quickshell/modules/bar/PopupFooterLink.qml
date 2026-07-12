// PopupFooterLink — GNOME Quick Settings footer link.
// Plain dim text, no underline, 48px height, with top divider.
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string label: ""
    signal clicked()

    implicitHeight: 48
    implicitWidth: parent?.width ?? 0
    Layout.fillWidth: true

    // Top divider to separate from content
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: TuiStyle.line
        opacity: 0.10
    }

    StyledText {
        anchors {
            left: parent.left
            leftMargin: 20
            verticalCenter: parent.verticalCenter
        }
        text: root.label
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.normal + 1   // ~16px
        font.weight: Font.Normal
        // No underline — GNOME style
        color: mouse.containsMouse ? TuiStyle.fg : TuiStyle.dim
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
