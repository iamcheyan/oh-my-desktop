import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

DialogListItem {
    id: root
    required property string entry
    signal itemClicked()

    verticalPadding: 4
    active: selected

    onClicked: {
        Cliphist.copy(entry);
        root.itemClicked();
    }

    readonly property bool isImage: Cliphist.entryIsImage(entry)
    readonly property string cleanText: StringUtils.cleanCliphistEntry(entry)

    // Image dimensions from entry string
    readonly property int imgW: {
        const match = entry.match(/(\d+)x(\d+)/);
        return match ? parseInt(match[1]) : 0;
    }
    readonly property int imgH: {
        const match = entry.match(/(\d+)x(\d+)/);
        return match ? parseInt(match[2]) : 0;
    }

    contentItem: Item {
        anchors {
            fill: parent
            topMargin: root.verticalPadding
            bottomMargin: root.verticalPadding
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
        }
        implicitHeight: rowLayout.implicitHeight

        RowLayout {
            id: rowLayout
            anchors.fill: parent
            spacing: 10

            CosmicIcon {
                iconSize: Appearance.font.pixelSize.larger
                name: root.isImage ? "actions/insert-image-symbolic" : "actions/document-open-symbolic"
                color: Appearance.tiling.textDim
            }

            StyledText {
                Layout.fillWidth: true
                color: Appearance.tiling.text
                elide: Text.ElideRight
                text: root.isImage ? `${root.imgW}x${root.imgH} image` : root.cleanText
                textFormat: Text.PlainText
                font.pixelSize: Appearance.font.pixelSize.small
                font.family: Appearance.font.family.monospace
            }
        }
    }

    // Proportional thumbnail dimensions (max 280px on longest side)
    readonly property real thumbMaxDim: 280
    readonly property real thumbScale: {
        if (imgW === 0 || imgH === 0) return 1;
        return Math.min(thumbMaxDim / imgW, thumbMaxDim / imgH, 1);
    }
    readonly property real thumbW: Math.round(imgW * thumbScale)
    readonly property real thumbH: Math.round(imgH * thumbScale)
    readonly property real thumbPad: 6

    // Floating thumbnail popup for images on hover
    Popup {
        id: thumbPopup
        parent: root
        x: -(root.thumbW + root.thumbPad * 2 + 12)
        y: (root.height - (root.thumbH + root.thumbPad * 2)) / 2
        width: root.thumbW + root.thumbPad * 2
        height: root.thumbH + root.thumbPad * 2
        visible: false
        padding: 0
        margins: 0
        clip: false
        closePolicy: Popup.NoAutoClose

        background: Rectangle {
            color: Appearance.colors.colLayer1
            border.width: 1
            border.color: Appearance.colors.colOutlineVariant
            radius: 8
            clip: true

            Rectangle {
                anchors.fill: parent
                anchors.margins: root.thumbPad
                radius: 4
                color: Appearance.colors.colLayer0
                clip: true

                Loader {
                    anchors.fill: parent
                    active: thumbPopup.visible
                    sourceComponent: CliphistImage {
                        entry: root.entry
                        maxWidth: root.thumbW
                        maxHeight: root.thumbH
                    }
                }
            }
        }
    }

    onHoveredChanged: {
        if (isImage) {
            thumbPopup.visible = hovered;
        }
    }

    onSelectedChanged: {
        if (isImage && !selected) {
            thumbPopup.visible = false;
        }
    }
}
