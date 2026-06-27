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
        color: root.pressed ? Appearance.tiling.bgActive
            : root.hovered || root.toggled ? Appearance.tiling.bgHover
            : "transparent"
        border.width: Appearance.tiling.borderWidth
        border.color: root.toggled ? Appearance.tiling.borderFocus
            : root.hovered ? Appearance.tiling.borderFocus
            : Appearance.tiling.border
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 5

        MaterialSymbol {
            visible: root.buttonIcon !== ""
            text: root.buttonIcon
            iconSize: Appearance.font.pixelSize.large
            color: root.toggled ? Appearance.tiling.textBright : Appearance.tiling.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        StyledText {
            visible: root.buttonText !== ""
            text: root.buttonText
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.toggled ? Appearance.tiling.textBright : Appearance.tiling.text
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
