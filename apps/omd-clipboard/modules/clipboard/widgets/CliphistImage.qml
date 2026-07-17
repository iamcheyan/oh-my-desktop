import QtQuick
import Quickshell
import Quickshell.Io
import "../../../services"

Rectangle {
    id: root
    property string entry
    property real maxWidth: 0
    property real maxHeight: 0
    property bool active: true

    property string imageDecodePath: ClipboardStyle.cliphistDecode
    property string imageSource: ""

    readonly property var imageMeta: {
        if (!root.entry)
            return ({ num: 0, w: 0, h: 0 });
        const m = root.entry.match(/^(\d+)\t\[\[.*?(\d+)x(\d+).*?\]\]$/);
        return m ? ({ num: parseInt(m[1]), w: parseInt(m[2]), h: parseInt(m[3]) }) : ({ num: 0, w: 0, h: 0 });
    }
    readonly property int entryNumber: imageMeta.num
    readonly property int imageWidth: imageMeta.w
    readonly property int imageHeight: imageMeta.h
    readonly property real scale: {
        if (root.imageWidth <= 0 || root.imageHeight <= 0 || root.maxWidth <= 0 || root.maxHeight <= 0)
            return 0;
        return Math.min(root.maxWidth / imageWidth, root.maxHeight / imageHeight, 1);
    }

    color: ClipboardStyle.bg
    radius: ClipboardStyle.radius
    implicitHeight: Math.max(0, imageHeight * scale)
    implicitWidth: Math.max(0, imageWidth * scale)
    clip: true

    function decodeImage() {
        if (entry && active && entryNumber > 0) {
            imageSource = "";
            checkAndDecode.running = false;
            const num = entryNumber;
            const filePath = `${imageDecodePath}/${num}`;
            checkAndDecode.pendingFilePath = filePath;
            checkAndDecode.command = ["bash", "-c",
                `mkdir -p '${imageDecodePath}'; if [ ! -s '${filePath}' ]; then tmp='${filePath}.tmp.'$$; trap 'rm -f "$tmp"' EXIT; printf '%s' '${num}' | ${Cliphist.cliphistBinary} decode > "$tmp" 2>/dev/null && [ -s "$tmp" ] && mv -f "$tmp" '${filePath}'; fi`];
            checkAndDecode.running = true;
        } else {
            imageSource = "";
            checkAndDecode.running = false;
        }
    }

    onEntryChanged: decodeTimer.restart()
    onActiveChanged: {
        if (active)
            decodeTimer.restart();
        else {
            decodeTimer.stop();
            checkAndDecode.running = false;
            imageSource = "";
        }
    }

    Component.onCompleted: decodeTimer.restart()

    Timer {
        id: decodeTimer
        interval: 50
        repeat: false
        onTriggered: root.decodeImage()
    }

    Process {
        id: checkAndDecode
        property string pendingFilePath: ""
        command: ["true"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && checkAndDecode.pendingFilePath !== "")
                root.imageSource = checkAndDecode.pendingFilePath;
        }
    }

    Image {
        id: image
        anchors.fill: parent
        source: imageSource ? Qt.resolvedUrl(`file://${imageSource}`) : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        cache: false
    }
}
