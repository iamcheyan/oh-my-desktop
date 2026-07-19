pragma ComponentBehavior: Bound
pragma Singleton
import qs.modules.common
import qs.modules.common.utils
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import Qt.labs.synchronizer
import Quickshell

Singleton {
    id: root

    enum Action {
        Copy,
        Edit,
        Search,
        CharRecognition,
        Record,
        RecordWithSound
    }

    property string imageSearchEngineBaseUrl: Config.options.search.imageSearch.imageSearchEngineBaseUrl
    property string fileUploadApiEndpoint: "https://uguu.se/upload"

    function quote(value) {
        return `'${StringUtils.shellSingleQuoteEscape(value)}'`;
    }

    function regionString(x, y, width, height) {
        const rx = Math.round(x);
        const ry = Math.round(y);
        const rw = Math.round(width);
        const rh = Math.round(height);
        return `${rx},${ry} ${rw}x${rh}`;
    }

    function annotationCommand() {
        return `${Config.options.regionSelector.annotation.useSatty ? "satty" : "swappy"} -f -`;
    }

    function uploadCurrentTempCommand() {
        return `curl -sF files[]=@"$tmpFile" ${quote(root.fileUploadApiEndpoint)} | jq -r '.files[0].url'`;
    }

    function tempFilePrefixForAction(action) {
        switch (action) {
            case ScreenshotAction.Action.Search:
                return "omd-search";
            case ScreenshotAction.Action.CharRecognition:
                return "omd-ocr";
            default:
                return "omd-screenshot";
        }
    }

    function getTempCaptureCommand(x, y, width, height, tempPath) {
        const region = regionString(x, y, width, height);
        return ["bash", "-c", `grim -g ${quote(region)} ${quote(tempPath)}`];
    }

    function getSnapshotCropCommand(x, y, width, height, snapshotPath, tempPath) {
        const rx = Math.round(x);
        const ry = Math.round(y);
        const rw = Math.round(width);
        const rh = Math.round(height);
        return ["bash", "-c",
            `magick ${quote(snapshotPath)} -crop ${rw}x${rh}+${rx}+${ry} +repage ${quote(tempPath)}`
        ];
    }

    function getRegionCommand(x, y, width, height, action, saveDir = "") {
        const region = regionString(x, y, width, height);
        const regionArg = quote(region);
        const tempPrefix = tempFilePrefixForAction(action);

        switch (action) {
            case ScreenshotAction.Action.Record:
                return ["bash", "-c", `${quote(Directories.recordScriptPath)} --region ${regionArg}`];
            case ScreenshotAction.Action.RecordWithSound:
                return ["bash", "-c", `${quote(Directories.recordScriptPath)} --region ${regionArg} --sound`];
            default: {
                const command = `tmpFile=$(mktemp /tmp/${tempPrefix}.XXXXXX.png) && ` +
                    `trap 'rm -f "$tmpFile"' EXIT && ` +
                    `grim -g ${regionArg} "$tmpFile" && ` +
                    tempFileActionScript("$tmpFile", action, saveDir, false);
                return ["bash", "-c", command];
            }
        }
    }

    function tempFileActionScript(tempFileExpression, action, saveDir = "", installCleanupTrap = true) {
        const setup = installCleanupTrap
            ? `tmpFile=${quote(tempFileExpression)}; trap 'rm -f "$tmpFile"' EXIT; `
            : "";

        switch (action) {
            case ScreenshotAction.Action.Copy:
                if (saveDir === "") {
                    return `${setup}cat "$tmpFile" | wl-copy`;
                }
                return `${setup}saveDir=${quote(saveDir)}; ` +
                    `mkdir -p "$saveDir" && ` +
                    `savePath="$saveDir/screenshot-$(date '+%Y-%m-%d_%H.%M.%S').png" && ` +
                    `cat "$tmpFile" | tee "$savePath" | wl-copy`;
            case ScreenshotAction.Action.Edit:
                return `${setup}cat "$tmpFile" | ${annotationCommand()}`;
            case ScreenshotAction.Action.Search:
                return `${setup}xdg-open "${root.imageSearchEngineBaseUrl}$(${uploadCurrentTempCommand()})"`;
            case ScreenshotAction.Action.CharRecognition:
                return `${setup}$HOME/.config/omd/bin/omd-ocr "$tmpFile" 2>/dev/null | wl-copy`;
            case ScreenshotAction.Action.Record:
            case ScreenshotAction.Action.RecordWithSound:
                console.warn("[Region Selector] Record actions require a selected region, not a temp file.");
                return `${setup}true`;
            default:
                console.warn("[Region Selector] Unknown snip action, skipping snip.");
                return `${setup}false`;
        }
    }

    function getTempFileCommand(tempPath, action, saveDir = "") {
        return ["bash", "-c", tempFileActionScript(tempPath, action, saveDir, true)];
    }

    function getCommand(x, y, width, height, screenshotPath, action, saveDir = "") {
        const rx = Math.round(x);
        const ry = Math.round(y);
        const rw = Math.round(width);
        const rh = Math.round(height);
        const cropBase = `magick "$screenshotFile" -crop ${rw}x${rh}+${rx}+${ry} +repage`;
        const tempPrefix = tempFilePrefixForAction(action);

        switch (action) {
            case ScreenshotAction.Action.Record:
            case ScreenshotAction.Action.RecordWithSound:
                return getRegionCommand(x, y, width, height, action, saveDir);
            default: {
                const command = `tmpFile=$(mktemp /tmp/${tempPrefix}.XXXXXX.png) && ` +
                    `screenshotFile=${quote(screenshotPath)} && ` +
                    `trap 'rm -f "$tmpFile" "$screenshotFile"' EXIT && ` +
                    `${cropBase} "$tmpFile" && ` +
                    tempFileActionScript("$tmpFile", action, saveDir, false);
                return ["bash", "-c", command];
            }
        }
    }

    function getGrimCommand(x, y, width, height, action, saveDir = "") {
        return getRegionCommand(x, y, width, height, action, saveDir);
    }
}
