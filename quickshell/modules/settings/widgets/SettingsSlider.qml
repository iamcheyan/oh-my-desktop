import qs.modules.settings
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Slider {
    id: sliderRoot
    property color trackColor: SettingsTokens.line
    property color highlightColor: SettingsTokens.accent
    property color handleColor: SettingsTokens.fg

    Layout.preferredHeight: 28
    from: 0
    to: 1
    leftPadding: 0
    rightPadding: 0

    background: Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: 0
        width: sliderRoot.width
        height: 6
        radius: 3
        color: sliderRoot.trackColor

        Rectangle {
            width: sliderRoot.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: sliderRoot.highlightColor
        }
    }

    handle: Rectangle {
        x: sliderRoot.visualPosition * (sliderRoot.width - width)
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        radius: 8
        color: sliderRoot.handleColor
        border.width: 2
        border.color: sliderRoot.pressed ? sliderRoot.highlightColor : SettingsTokens.buttonBorder
        Behavior on border.color { ColorAnimation { duration: 100 } }
    }
}