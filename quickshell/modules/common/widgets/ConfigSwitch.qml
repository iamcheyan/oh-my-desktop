import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property string buttonIcon
    property string text: ""
    property bool checked: false
    property bool hovered: hoverArea.containsMouse
    property alias iconSize: iconWidget.font.pixelSize

    Layout.fillWidth: true
    implicitHeight: Math.max(contentRow.implicitHeight + 12, 30)
    opacity: root.enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: root.hovered ? Appearance.tiling.bgHover : "transparent"
        border.width: root.hovered ? Appearance.tiling.borderWidth : 0
        border.color: Appearance.tiling.border
    }

    RowLayout {
        id: contentRow
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 8
            rightMargin: 8
        }
        spacing: 8

        StyledText {
            text: root.checked ? "[x]" : "[ ]"
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.checked ? Appearance.tiling.accentBright : Appearance.tiling.textDim
        }

        StyledText {
            id: iconWidget
            visible: root.buttonIcon && root.buttonIcon.length > 0
            text: root.buttonIcon
            font.family: Appearance.font.family.iconMaterial
            font.pixelSize: Appearance.font.pixelSize.large
            color: Appearance.tiling.textDim
        }

        StyledText {
            Layout.fillWidth: true
            text: root.text
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.tiling.text
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.checked = !root.checked
    }
}
