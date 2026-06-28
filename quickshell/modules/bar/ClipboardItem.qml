import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property string entry
    property int itemIndex: 0
    property bool selected: false

    signal itemClicked()
    signal hoveredChanged(bool hovered)

    readonly property bool isImage: Cliphist.entryIsImage(entry)
    readonly property string cleanText: StringUtils.cleanCliphistEntry(entry)
    readonly property int imgW: {
        const match = entry.match(/(\d+)x(\d+)/);
        return match ? parseInt(match[1]) : 0;
    }
    readonly property int imgH: {
        const match = entry.match(/(\d+)x(\d+)/);
        return match ? parseInt(match[2]) : 0;
    }

    implicitHeight: 42
    color: selected ? TuiStyle.selection : mouseArea.containsMouse ? "#333333" : "transparent"
    border.width: 0
    radius: TuiStyle.radius
    clip: true

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: root.hoveredChanged(containsMouse)
        onClicked: {
            Cliphist.paste(root.entry);
            root.itemClicked();
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: root.isImage ? `${root.imgW}x${root.imgH} image` : root.cleanText
                elide: Text.ElideRight
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: root.selected ? Font.DemiBold : Font.Medium
                color: root.selected ? TuiStyle.fg : TuiStyle.fg
            }

            StyledText {
                Layout.fillWidth: true
                text: root.isImage ? "binary clipboard entry" : root.entry.replace(/^\s*\S+\s+/, "").slice(0, 96)
                elide: Text.ElideRight
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: TuiStyle.dim
                visible: text.length > 0
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: TuiStyle.line
        opacity: root.selected ? 0 : 0.3
    }
}
