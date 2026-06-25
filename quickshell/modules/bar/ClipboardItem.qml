import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root
    required property string entry
    property int index: 0
    property bool selected: false
    signal itemClicked()
    signal hoveredChanged(bool hovered)

    property string monoFont: "JetBrainsMono Nerd Font, monospace"
    property color bgColor: selected ? "#2a4a6a" : (mouseArea.containsMouse ? "#222222" : "#1a1a1a")
    property color textColor: "#ffffff"
    property color dimColor: "#888888"

    height: 28
    color: bgColor

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
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        // Index number
        Text {
            text: (root.index + 1).toString().padStart(3, ' ')
            font.family: root.monoFont
            font.pixelSize: 12
            color: root.dimColor
            Layout.preferredWidth: 30
        }

        // Type indicator
        Text {
            text: root.isImage ? "[IMG]" : "[TXT]"
            font.family: root.monoFont
            font.pixelSize: 12
            color: root.isImage ? "#a3be8c" : "#4c7899"
            Layout.preferredWidth: 40
        }

        // Content
        Text {
            Layout.fillWidth: true
            text: root.entry
            font.family: root.monoFont
            font.pixelSize: 12
            color: root.textColor
            elide: Text.ElideRight
        }
    }
}
