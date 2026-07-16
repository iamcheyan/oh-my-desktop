import qs.modules.common
import QtQuick
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root

    property int contentPadding: 14
    default property alias content: contentContainer.data

    // Offscreen OpacityMask gives cleaner rounded corners, but rebuilding the
    // layer FBO on every size change flashes the whole shell. Height-variable
    // bar popups set this false; see docs/bar-popup-height-stability.md.
    property bool useLayerMask: true

    // Match BarContextMenu / WindowDialog shell chrome
    color: TuiStyle.bg
    border.width: TuiStyle.borderWidth
    border.color: TuiStyle.menuBorder
    radius: TuiStyle.shellRadius
    clip: true

    layer.enabled: useLayerMask
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
