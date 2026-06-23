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


}
