pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common
import Quickshell.Io

Singleton {
    id: root

    readonly property string themePath: `${Directories.stateHome}/sumika-shell/theme/current/quickshell.json`
    readonly property color accent: themeJson.primary || "#eeeeee"
    readonly property color background: themeJson.background || "#050505"
    readonly property color foreground: themeJson.backgroundText || "#f4f4f4"
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.18)
    readonly property color accentSofter: Qt.rgba(accent.r, accent.g, accent.b, 0.10)
    readonly property color accentBorder: Qt.rgba(accent.r, accent.g, accent.b, 0.78)
    readonly property color accentActiveBorder: Qt.rgba(accent.r, accent.g, accent.b, 0.88)
    readonly property color tintedBackground: {
        var r = background.r * 0.92 + accent.r * 0.08;
        var g = background.g * 0.92 + accent.g * 0.08;
        var b = background.b * 0.92 + accent.b * 0.08;
        return Qt.rgba(r, g, b, 1.0);
    }

    function reload() {
        themeFile.reload();
    }

    IpcHandler {
        target: "theme"

        function reload(): void {
            root.reload();
        }
    }

    FileView {
        id: themeFile
        path: root.themePath
        watchChanges: true

        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound)
                console.warn(`[OmarchyTheme] Failed to load ${root.themePath}: ${error}`);
        }

        JsonAdapter {
            id: themeJson
            property string primary: "#eeeeee"
            property string background: "#050505"
            property string backgroundText: "#f4f4f4"
        }
    }
}
