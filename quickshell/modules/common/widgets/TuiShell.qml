import qs.modules.common
import QtQuick

Rectangle {
    id: root

    property int contentPadding: 14
    default property alias content: contentContainer.data

    color: TuiStyle.bg
    border.width: TuiStyle.borderWidth
    border.color: TuiStyle.shellBorder
    radius: TuiStyle.radius
    clip: true

    Item {
        id: contentContainer
        anchors.fill: parent
        anchors.margins: root.contentPadding
    }
}
