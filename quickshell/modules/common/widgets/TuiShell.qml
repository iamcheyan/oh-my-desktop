import qs.modules.common
import QtQuick

Rectangle {
    id: root

    property int contentPadding: 14
    default property alias content: contentContainer.data

    color: TuiStyle.bg
    gradient: Gradient {
        GradientStop { position: 0.0; color: TuiStyle.shellGradientTop }
        GradientStop { position: 0.42; color: TuiStyle.shellGradientMid }
        GradientStop { position: 1.0; color: TuiStyle.shellGradientBottom }
    }
    border.width: TuiStyle.borderWidth
    border.color: TuiStyle.shellBorder
    radius: TuiStyle.shellRadius
    clip: true

    Item {
        id: contentContainer
        anchors.fill: parent
        anchors.margins: root.contentPadding
    }
}
