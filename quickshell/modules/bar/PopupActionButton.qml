// PopupActionButton — standardized header action icon.
// 36×36px touch target, 22px MaterialSymbol, hover background.
// Use in popup header rows for settings gears, clear buttons, etc.
import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string icon: ""
    property int iconSize: 22
    property color color: TuiStyle.muted
    property color colorHover: TuiStyle.fg

    signal clicked()

    implicitWidth: 36
    implicitHeight: 36

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: mouseArea.containsMouse ? TuiStyle.surfaceHover : "transparent"
    }

    MaterialSymbol {
        anchors.centerIn: parent
        text: root.icon
        iconSize: root.iconSize
        color: mouseArea.containsMouse ? root.colorHover : root.color
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
