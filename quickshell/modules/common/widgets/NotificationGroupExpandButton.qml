import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property int count
    required property bool expanded
    property real fontSize: Appearance?.font.pixelSize.small ?? 12
    property bool hovered: hoverArea.containsMouse
    signal clicked()

    implicitHeight: 24
    implicitWidth: Math.max(contentRow.implicitWidth + 10, 34)
    Layout.alignment: Qt.AlignVCenter
    Layout.fillHeight: false

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: root.hovered ? Appearance.tiling.bgHover : Appearance.tiling.bg
        border.width: Appearance.tiling.borderWidth
        border.color: root.expanded ? Appearance.tiling.borderFocus : Appearance.tiling.border
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 4

        StyledText {
            visible: root.count > 1
            text: root.count
            font.pixelSize: root.fontSize
            font.family: Appearance.font.family.monospace
            color: Appearance.tiling.text
        }

        StyledText {
            text: root.expanded ? "-" : "+"
            font.pixelSize: root.fontSize
            font.family: Appearance.font.family.monospace
            color: Appearance.tiling.textBright
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
