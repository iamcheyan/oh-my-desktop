import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    readonly property string latestEntry: Cliphist.entries.length > 0 ? Cliphist.entries[0] : ""
    readonly property bool hasEntries: latestEntry !== ""
    readonly property bool isImage: hasEntries && Cliphist.entryIsImage(latestEntry)
    readonly property string cleanText: hasEntries && !isImage ? StringUtils.cleanCliphistEntry(latestEntry) : ""
    readonly property int contentWidth: 300

    StyledPopupContent {
        preferredWidth: root.contentWidth

        StyledPopupValueRow {
            icon: root.isImage
                ? NerdIconMap.screenshot
                : NerdIconMap.contentPaste
            label: Translation.tr("Clipboard:")
            value: {
                if (!root.hasEntries) return Translation.tr("Empty")
                if (root.isImage) {
                    var match = root.latestEntry.match(/(\d+)x(\d+)/)
                    return match ? `${match[1]}x${match[2]} ${Translation.tr("image")}`
                                 : Translation.tr("Image")
                }
                return root.cleanText
            }
        }

        CliphistImage {
            visible: root.isImage
            Layout.alignment: Qt.AlignHCenter
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            entry: root.isImage ? root.latestEntry : ""
            maxWidth: root.contentWidth - 16
            maxHeight: 160
        }
    }
}