import qs.modules.common
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    default property alias cells: cellRow.data

    Layout.fillWidth: true
    Layout.preferredHeight: 50
    implicitHeight: 50
    radius: 8
    color: TuiStyle.control
    border.width: 1
    border.color: TuiStyle.line
    clip: true

    RowLayout {
        id: cellRow
        anchors.fill: parent
        spacing: 0
    }
}
