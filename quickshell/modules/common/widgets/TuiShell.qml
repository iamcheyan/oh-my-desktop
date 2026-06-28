import qs.modules.common
import QtQuick

Rectangle {
    id: root

    property int contentPadding: 14
    default property alias content: contentContainer.data

    color: TuiStyle.bg
    gradient: Gradient {
        GradientStop { position: 0.0; color: "#ee151515" }
        GradientStop { position: 0.42; color: "#e7080808" }
        GradientStop { position: 1.0; color: "#ef111111" }
    }
    border.width: TuiStyle.borderWidth
    border.color: "#8f8f8f"
    radius: 18
    clip: true

    Item {
        id: contentContainer
        anchors.fill: parent
        anchors.margins: root.contentPadding
    }
}