import QtQuick
import Quickshell
import Quickshell.Io
import "../../../services"

Rectangle {
    id: root
    property string entry
    property real maxWidth: 0
    property real maxHeight: 0

    property string imageDecodePath: Directories.cliphistDecode
    property string imageDecodeFileName: `${entryNumber}`
    property string imageDecodeFilePath: `${imageDecodePath}/${imageDecodeFileName}`
    property string imageSource: ""

    property int entryNumber: {
        if (!root.entry)
            return 0;
        const match = root.entry.match(/^(\d+)\t/);
        return match ? parseInt(match[1]) : 0;
    }
    property int imageWidth: {
        if (!root.entry)
            return 0;
        const match = root.entry.match(/(\d+)x(\d+)/);
        return match ? parseInt(match[1]) : 0;
    }
    property int imageHeight: {
        if (!root.entry)
            return 0;
        const match = root.entry.match(/(\d+)x(\d+)/);
        return match ? parseInt(match[2]) : 0;
    }
    property real scale: {
        if (root.imageWidth <= 0 || root.imageHeight <= 0 || root.maxWidth <= 0 || root.maxHeight <= 0)
            return 0;
        return Math.min(root.maxWidth / imageWidth, root.maxHeight / imageHeight, 1);
    }

    color: TuiStyle.bg
    radius: TuiStyle.radius
    implicitHeight: Math.max(0, imageHeight * scale)
    implicitWidth: Math.max(0, imageWidth * scale)
    clip: true

    function decodeImage() {
        if (entry) {
            imageSource = "";
            checkAndDecode.running = false;
            const num = entryNumber;
            const filePath = `${imageDecodePath}/${num}`;
            const escaped = StringUtils.shellSingleQuoteEscape(entry);
            checkAndDecode.command = ["bash", "-c", `if file '${filePath}' 2>/dev/null | grep -qi 'image\\|png\\|jpeg\\|bmp\\|webp\\|gif'; then echo cached; else rm -f '${filePath}' && printf '${escaped}' | ${Cliphist.cliphistBinary} decode > '${filePath}' 2>/dev/null && file '${filePath}' | grep -qi 'image\\|png\\|jpeg\\|bmp\\|webp\\|gif' && echo decoded; fi`];
            checkAndDecode.running = true;
        } else {
            imageSource = "";
            checkAndDecode.running = false;
        }
    }

    onEntryChanged: {
        decodeImage();
    }

    Component.onCompleted: {
        decodeImage();
    }

    Process {
        id: checkAndDecode
        command: ["bash", "-c", `if file '${imageDecodeFilePath}' 2>/dev/null | grep -qi 'image\\|png\\|jpeg\\|bmp\\|webp\\|gif'; then echo cached; else rm -f '${imageDecodeFilePath}' && printf '${StringUtils.shellSingleQuoteEscape(root.entry)}' | ${Cliphist.cliphistBinary} decode > '${imageDecodeFilePath}' 2>/dev/null && file '${imageDecodeFilePath}' | grep -qi 'image\\|png\\|jpeg\\|bmp\\|webp\\|gif' && echo decoded; fi`]
        stdout: StdioCollector {
            onStreamFinished: {
                const result = text.trim();
                if (result === "cached" || result === "decoded") {
                    root.imageSource = imageDecodeFilePath;
                }
            }
        }
    }

    Image {
        id: image
        anchors.fill: parent
        source: imageSource ? Qt.resolvedUrl(`file://${imageSource}`) : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        cache: true
    }
}
