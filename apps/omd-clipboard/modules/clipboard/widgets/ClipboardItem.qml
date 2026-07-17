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
    signal mouseMoved()

    readonly property bool isImage: Cliphist.entryIsImage(entry)
    readonly property string cleanText: ClipboardStyle.cleanCliphistEntry(entry)

    implicitHeight: 34
    color: "transparent"

    Rectangle {
        anchors {
            fill: parent
            leftMargin: 6
            rightMargin: 6
            topMargin: 2
            bottomMargin: 2
        }
        radius: 6
        color: root.selected ? ClipboardStyle.surfaceSelected : mouseArea.containsMouse ? ClipboardStyle.surfaceHover : "transparent"
        visible: root.selected || mouseArea.containsMouse
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: root.hoveredChanged(containsMouse)
        onPositionChanged: root.mouseMoved()
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

        Rectangle {
            visible: root.isImage
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter
            color: ClipboardStyle.surface
            radius: 4
            clip: true

            // Unified image icon in the list — decode is deferred to the
            // preview card on hover/select to avoid per-row Process spawn.
            StyledText {
                anchors.centerIn: parent
                visible: root.isImage
                text: "image"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 13
                color: ClipboardStyle.dim
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: root.isImage ? "Image" : root.cleanText.replace(/[\r\n]+/g, " ")
            textFormat: Text.PlainText
            elide: Text.ElideRight
            maximumLineCount: 1
            color: ClipboardStyle.fg
            font.family: ClipboardStyle.fontFamily
            font.pixelSize: 14
        }

        Rectangle {
            visible: root.isImage && (root.selected || mouseArea.containsMouse)
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter
            color: pathMouse.containsMouse ? ClipboardStyle.accentSoft : "transparent"
            radius: 4

            StyledText {
                anchors.centerIn: parent
                text: "⇲"
                font.family: ClipboardStyle.fontFamily
                font.pixelSize: 16
                color: pathMouse.containsMouse ? ClipboardStyle.accent : ClipboardStyle.dim
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
    }
}
