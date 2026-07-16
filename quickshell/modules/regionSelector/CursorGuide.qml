import QtQuick

Item {
    id: root
    property var action
    property var selectionMode

    implicitWidth: 22
    implicitHeight: 22

    Rectangle {
        anchors.centerIn: parent
        width: 4
        height: 22
        color: "#b0000000"
    }

    Rectangle {
        anchors.centerIn: parent
        width: 2
        height: 22
        color: "#ffffff"
    }

    Rectangle {
        anchors.centerIn: parent
        width: 22
        height: 4
        color: "#b0000000"
    }

    Rectangle {
        anchors.centerIn: parent
        width: 22
        height: 2
        color: "#ffffff"
    }
}
