import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property string buttonIcon: ""
    property string buttonText: ""
    property bool toggled: false
    property bool hovered: hoverArea.containsMouse
    property bool pressed: hoverArea.pressed
    property real buttonHeight: 26
    property real horizontalPadding: 8
    signal clicked()

    implicitHeight: buttonHeight
    implicitWidth: Math.max(contentRow.implicitWidth + horizontalPadding * 2, buttonHeight)
    Layout.fillHeight: false

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: root.pressed ? "#222222"
            : root.hovered || root.toggled ? "#333333"
            : "transparent"
        border.width: TuiStyle.borderWidth
        border.color: root.toggled ? TuiStyle.accent
            : root.hovered ? TuiStyle.accent
            : TuiStyle.line
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 5

        MaterialSymbol {
            visible: root.buttonIcon !== ""
            text: root.buttonIcon
            iconSize: Appearance.font.pixelSize.large
            color: root.toggled ? TuiStyle.fg : TuiStyle.fg
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        StyledText {
            visible: root.buttonText !== ""
            text: root.buttonText
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.toggled ? TuiStyle.fg : TuiStyle.fg
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
