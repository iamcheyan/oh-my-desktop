import qs.modules.common
import QtQuick
import Qt5Compat.GraphicalEffects

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

    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
        }
    }

    Item {
        id: contentContainer
        anchors.fill: parent
        anchors.margins: root.contentPadding
    }
}
