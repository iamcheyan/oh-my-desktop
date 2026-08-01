pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string themePath: `${Quickshell.env("HOME")}/.local/state/sumika-shell/theme/current/quickshell.json`
    readonly property color fg: "#ffffff"
    readonly property color dim: "#a8a8a8"
    readonly property color muted: "#777777"
    readonly property color bg: themeJson.background || "#050505"
    readonly property color panel: "#101010"
    readonly property color surface: "#181818"
    readonly property color surfaceHover: "#242424"
    readonly property color surfaceSelected: "#2b2b2b"
    readonly property color line: "#4a4a4a"
    readonly property color separator: "#303030"
    readonly property color accent: themeJson.primary || "#eeeeee"
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.18)
    readonly property int radius: 14

    readonly property string fontFamily: "MesloLGS Nerd Font"
    readonly property int fontPixelSmall: 12

    readonly property string cliphistDecode: (Quickshell.env("HOME") ?? "") + "/.cache/media/cliphist"

    FileView {
        id: themeFile
        path: root.themePath
        watchChanges: true

        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound)
                console.warn(`[ClipboardStyle] Failed to load ${root.themePath}: ${error}`);
        }

        JsonAdapter {
            id: themeJson
            property string primary: "#eeeeee"
            property string background: "#050505"
            property string backgroundText: "#f4f4f4"
        }
    }

    function shellSingleQuoteEscape(str) {
        return String(str).replace(/'/g, "'\\''");
    }

    function cleanCliphistEntry(str: string): string {
        return str.replace(/^\d+\t/, "");
    }
}
