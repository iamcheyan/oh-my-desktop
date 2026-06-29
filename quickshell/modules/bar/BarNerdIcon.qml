import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

Item {
    id: root

    property alias text: icon.text
    property color color: Appearance.colors.colBarText
    property real iconSize: Config.options.bar.rightIconSize

    implicitWidth: Config.options.bar.rightIconSize
    implicitHeight: Config.options.bar.rightIconSize

    NerdIcon {
        id: icon
        anchors.centerIn: parent
        width: root.implicitWidth
        height: root.implicitHeight
        iconSize: root.iconSize
        color: root.color
    }
}
