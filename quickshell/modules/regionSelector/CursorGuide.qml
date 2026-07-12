import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

Item {
    id: root
    property var action
    property var selectionMode

    property bool showDescription: false

    implicitWidth: 36
    implicitHeight: 36

    Rectangle {
        id: circle
        anchors.centerIn: parent
        width: 36
        height: 36
        radius: 18
        color: "#000000"
        border.color: "#ffffff"
        border.width: 3

        // Horizontal line of crosshair
        Rectangle {
            anchors.centerIn: parent
            width: 16
            height: 3
            radius: 1
            color: "#ffffff"
        }

        // Vertical line of crosshair
        Rectangle {
            anchors.centerIn: parent
            width: 3
            height: 16
            radius: 1
            color: "#ffffff"
        }
    }
}
