import QtQuick
import QtQuick.Layouts
import "../../../services"

Rectangle {
    id: root

    required property string entry
    property int itemIndex: 0
    property bool selected: false
    signal itemClicked()
    signal hoveredChanged(bool hovered)
    signal pasteAsPathRequested(string entry)

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

    implicitHeight: 34
    color: "transparent"

    // Rounded Inset Selection/Hover Card
    Rectangle {
        anchors {
            fill: parent
            leftMargin: 6
            rightMargin: 6
            topMargin: 2
            bottomMargin: 2
        }
        radius: 6
        color: root.selected ? TuiStyle.accent : mouseArea.containsMouse ? "#323238" : "transparent"
        visible: root.selected || mouseArea.containsMouse
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
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 8

        // Thumbnail (only shown for images)
        Rectangle {
            visible: root.isImage
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter
            color: "#35353a"
            radius: 4
            clip: true

            CliphistImage {
                anchors.fill: parent
                visible: root.isImage
                entry: visible ? root.entry : ""
                active: visible
                maxWidth: 20
                maxHeight: 20
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: root.isImage ? `${root.imgW} × ${root.imgH} image` : root.cleanText.replace(/[\r\n]+/g, " ")
            elide: Text.ElideRight
            maximumLineCount: 1
            color: root.selected ? TuiStyle.bg : TuiStyle.fg
            font.family: Appearance.font.family.main
            font.pixelSize: 14
        }

        Rectangle {
            visible: root.isImage && (root.selected || mouseArea.containsMouse)
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter
            color: pathMouse.containsMouse ? "#5c5c62" : "transparent"
            radius: 4

            StyledText {
                anchors.centerIn: parent
                text: "folder_open"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 14
                color: root.selected ? TuiStyle.bg : "#ffffff"
            }

            MouseArea {
                id: pathMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    mouse.accepted = true;
                    root.pasteAsPathRequested(root.entry);
                }
            }
        }

        StyledText {
            visible: root.itemIndex < 9
            text: `${root.itemIndex + 1}`
            color: root.selected ? TuiStyle.bg : "#7c7c82"
            font.family: Appearance.font.family.main
            font.pixelSize: 11
        }
    }
}
