import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Rectangle {
    property string text: ""
    property int textAlignment: Text.AlignLeft
    height: 26
    Layout.fillWidth: true
    Layout.topMargin: 0
    color: Appearance.tiling.bgTitlebar
    radius: 0

    StyledText {
        anchors {
            left: textAlignment === Text.AlignLeft ? parent.left : undefined
            leftMargin: textAlignment === Text.AlignLeft ? 10 : 0
            horizontalCenter: textAlignment === Text.AlignHCenter ? parent.horizontalCenter : undefined
            verticalCenter: parent.verticalCenter
        }
        text: parent.text
        color: Appearance.tiling.textBright
        font {
            pixelSize: Appearance.font.pixelSize.small
            weight: Font.Bold
        }
    }
}