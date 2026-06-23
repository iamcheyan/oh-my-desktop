import QtQuick
import Qt5Compat.GraphicalEffects
import qs.modules.common

Item {
    id: root

    property string name: ""
    property real iconSize: Appearance?.font.pixelSize.small ?? 16
    property color color: Appearance?.tiling?.text ?? "#c5c8c6"

    readonly property string source: "file://" + Directories.assetsPath + "/cosmic-icons/" + name + ".svg"

    implicitWidth: iconSize
    implicitHeight: iconSize

    Image {
        id: iconImage
        anchors.fill: parent
        source: root.source
        sourceSize.width: root.iconSize * 2
        sourceSize.height: root.iconSize * 2
        smooth: true
        visible: false
    }

    ColorOverlay {
        anchors.fill: iconImage
        source: iconImage
        color: root.color
        cached: true
    }
}