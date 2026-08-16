pragma ComponentBehavior: Bound
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
    // Preview thumbnails are scaled to at most ~2x the largest preview box
    // (380x300) with magick — crisp on hidpi, but ~25x smaller and ~25x
    // cheaper to decode in QML than the original screenshot PNG
    // (e.g. 3840x2160 -> 720x405). Falls back to the raw decode when
    // magick is unavailable or chokes on the format.
    readonly property string thumbGeometry: "720x500>"

    readonly property var imageMeta: {
        if (!root.entry)
            return ({ num: 0, w: 0, h: 0 });
        const m = `${root.entry}`.match(/^(\d+)\t\[\[.*?(\d+)x(\d+).*?\]\]/);
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
    function decodeImage() {
        if (entry && active && entryNumber > 0) {
            imageSource = "";
            checkAndDecode.running = false;
            const num = entryNumber;
            const thumbPath = `${imageDecodePath}/${num}.preview.png`;
            checkAndDecode.pendingFilePath = thumbPath;
            checkAndDecode.command = ["bash", "-c",
                `mkdir -p '${imageDecodePath}'; if [ ! -s '${thumbPath}' ]; then tmp='${thumbPath}.tmp.'$$; raw="$tmp.rawtmp"; trap 'rm -f "$tmp" "$raw"' EXIT; printf '%s' '${num}' | ${Cliphist.cliphistBinary} decode > "$raw" 2>/dev/null || exit 1; [ -s "$raw" ] || exit 1; if command -v magick >/dev/null 2>&1 && magick "$raw[0]" -auto-orient -strip -resize '${thumbGeometry}' png:"$tmp" 2>/dev/null && [ -s "$tmp" ]; then :; else cp -f "$raw" "$tmp"; fi; mv -f "$tmp" '${thumbPath}'; fi`];
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
