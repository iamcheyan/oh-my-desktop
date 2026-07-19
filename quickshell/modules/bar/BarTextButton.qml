import qs.modules.common
import qs.modules.common.widgets
import QtQuick

MouseArea {
    id: root

    property alias text: label.text
    signal triggered()

    property int leadingPadding: 10
    property int trailingPadding: 10
    readonly property int buttonHeight: 28

    implicitWidth: label.implicitWidth + leadingPadding + trailingPadding
    implicitHeight: buttonHeight
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: root.triggered()

    Rectangle {
        id: hoverBg
        anchors.fill: parent
        radius: height / 2
        color: root.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    StyledText {
        id: label
        anchors.centerIn: parent
        font.pixelSize: 12
        font.variableAxes: ({
            "wght": 500,
            "wdth": 100,
        })
        color: Appearance.colors.colBarText
        opacity: root.containsMouse ? 1 : 0.85

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }
    }
}
