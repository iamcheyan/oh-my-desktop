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

    readonly property real scaleFactor: (typeof clipboardDialog !== "undefined") ? clipboardDialog.fontScale : 1.0
    implicitHeight: Math.round(54 * scaleFactor)
    color: selected ? TuiStyle.selection : mouseArea.containsMouse ? "#333333" : "transparent"
    border.width: 0
    radius: 0
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
        anchors.rightMargin: 6
        spacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            StyledText {
                id: mainText
                Layout.fillWidth: true
                text: root.isImage ? `${root.imgW}x${root.imgH} image` : root.cleanText
                wrapMode: Text.Wrap
                maximumLineCount: root.isImage ? 1 : 2
                elide: Text.ElideRight
                font.family: Appearance.font.family.main
                font.pixelSize: (Appearance?.font.pixelSize.small ?? 15) * scaleFactor
                font.weight: Font.Normal
                color: TuiStyle.fg
            }

            StyledText {
                Layout.fillWidth: true
                text: root.isImage ? "binary clipboard entry" : root.entry.replace(/^\s*\S+\s+/, "").slice(0, 96)
                elide: Text.ElideRight
                font.family: Appearance.font.family.main
                font.pixelSize: (Appearance?.font.pixelSize.smaller ?? 13) * scaleFactor
                color: TuiStyle.dim
                visible: root.isImage
            }
        }

        // Button: save image to /tmp and paste the file path
        Rectangle {
            id: copyPathBtn
            visible: root.isImage && (mouseArea.containsMouse || selected)
            width: 28
            height: 28
            radius: 6
            color: copyPathBtnMouse.containsMouse ? TuiStyle.accent : "#2a2a2a"
            border.width: 1
            border.color: copyPathBtnMouse.containsMouse ? TuiStyle.accent : TuiStyle.line
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: 2

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            StyledText {
                anchors.centerIn: parent
                text: "⇲"
                font.pixelSize: 14
                color: copyPathBtnMouse.containsMouse ? TuiStyle.bg : TuiStyle.dim
            }

            MouseArea {
                id: copyPathBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    mouse.accepted = true;
                    // Capture entry before dismiss closes the dialog
                    const capturedEntry = root.entry;
                    // Dismiss dialog first so focus returns to target window
                    root.itemClicked();
                    // Then save image + copy path + simulate paste (via Cliphist singleton)
                    Cliphist.pasteImagePath(capturedEntry);
                }
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
