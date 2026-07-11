import qs.modules.common
import QtQuick

Rectangle {
    id: root

    property int contentPadding: 14
    default property alias content: contentContainer.data

    // Match BarContextMenu / WindowDialog shell chrome
    color: TuiStyle.bg
    border.width: TuiStyle.borderWidth
    border.color: TuiStyle.menuBorder
    radius: TuiStyle.shellRadius
    clip: true

    Item {
        id: contentContainer
        anchors.fill: parent
        anchors.margins: root.contentPadding
    }
}
