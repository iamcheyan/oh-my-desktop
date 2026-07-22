// IconActionRow — full-width evenly-spaced icon buttons.
// Each child should be a PopupIconButton.
import qs
import QtQuick
import QtQuick.Layouts

Item {
    Layout.fillWidth: true
    Layout.leftMargin: 20
    Layout.rightMargin: 20
    Layout.topMargin: 4
    Layout.bottomMargin: 8
    implicitHeight: iconRowInner.implicitHeight

    RowLayout {
        id: iconRowInner
        anchors { left: parent.left; right: parent.right }
        spacing: 8
    }

    default property alias buttons: iconRowInner.data
}
