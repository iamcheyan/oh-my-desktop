import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    property string entry
    property real maxWidth
    property real maxHeight
    property bool blur: false
    property string blurText: "Image hidden"

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
        return Math.min(root.maxWidth / imageWidth, root.maxHeight / imageHeight, 1);
    }

    color: Appearance.colors.colLayer1
    radius: Appearance.rounding.small
    implicitHeight: imageHeight * scale
    implicitWidth: imageWidth * scale
    clip: true

    Component.onCompleted: {
        // Check if cached file is a valid image, otherwise decode fresh
        checkAndDecode.running = true;
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

    StyledImage {
        id: image
        anchors.fill: parent

        source: imageSource ? Qt.resolvedUrl(`file://${imageSource}`) : ""
        fillMode: Image.PreserveAspectFit
        antialiasing: true
        asynchronous: true
        cache: true

        width: root.imageWidth * root.scale
        height: root.imageHeight * root.scale
    }

    Loader {
        id: blurLoader
        active: root.blur
        anchors.fill: image
        sourceComponent: GaussianBlur {
            source: image
            radius: 35
            samples: radius * 2 + 1

            Rectangle {
                anchors.fill: parent
                color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.5)

                Column {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    MaterialSymbol {
                        visible: width <= image.width
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "visibility_off"
                        font.pixelSize: 28
                    }
                    StyledText {
                        visible: width <= image.width
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.blurText
                        color: Appearance.colors.colOnSurface
                        font.pixelSize: Appearance.font.pixelSize.smallie
                    }
                }
            }
        }
    }
}
