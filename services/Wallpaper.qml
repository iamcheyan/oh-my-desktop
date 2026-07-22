pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string revisionPath: `${Directories.sumikaStateHome}/wallpaper/revision`
    property int revision: 0
    readonly property string configuredPath: {
        const path = Config.options?.background?.wallpaperPath ?? "";
        if (path === "~")
            return Quickshell.env("HOME");
        if (path.startsWith("~/"))
            return `${Quickshell.env("HOME")}/${path.slice(2)}`;
        return path;
    }
    readonly property url requestedUrl: root.versionedUrl(root.configuredPath)
    property url readyUrl: ""

    function versionedUrl(path) {
        if (!path)
            return "";
        return `${Qt.resolvedUrl(path)}?revision=${root.revision}`;
    }

    FileView {
        id: revisionFile
        path: root.revisionPath
        watchChanges: true

        onFileChanged: revisionFile.reload()
        onLoaded: root.revision++
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound)
                console.warn(`[Wallpaper] Failed to load ${root.revisionPath}: ${error}`);
        }
    }
}
