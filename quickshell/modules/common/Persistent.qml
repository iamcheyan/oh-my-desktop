pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property alias states: persistentStatesJsonAdapter
    property string fileDir: Directories.state
    property string fileName: "states.json"
    property string filePath: `${root.fileDir}/${root.fileName}`

    property bool ready: false
    property string previousHyprlandInstanceSignature: ""
    property bool isNewHyprlandInstance: previousHyprlandInstanceSignature !== states.hyprlandInstanceSignature

    onReadyChanged: {
        root.previousHyprlandInstanceSignature = root.states.hyprlandInstanceSignature
        root.states.hyprlandInstanceSignature = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || ""

        if (root.ready) {
            const mode = root.states.display?.optimization ?? "balanced"
            let evalStr = ""
            if (mode === "performance") {
                evalStr = "hl.config({ decoration = { blur = { enabled = false } }, animations = { enabled = false } })"
            } else if (mode === "balanced") {
                evalStr = "hl.config({ decoration = { blur = { enabled = true, passes = 1 } }, animations = { enabled = true } })"
            } else if (mode === "visuals") {
                evalStr = "hl.config({ decoration = { blur = { enabled = true, passes = 2 } }, animations = { enabled = true } })"
            }
            if (evalStr !== "") {
                Quickshell.execDetached(["hyprctl", "eval", evalStr])
            }
        }
    }

    Timer {
        id: fileReloadTimer
        interval: 100
        repeat: false
        onTriggered: {
            persistentStatesFileView.reload()
        }
    }

    Timer {
        id: fileWriteTimer
        interval: 100
        repeat: false
        onTriggered: {
            persistentStatesFileView.writeAdapter()
        }
    }

    FileView {
        id: persistentStatesFileView
        path: root.filePath

        watchChanges: true
        onFileChanged: fileReloadTimer.restart()
        onAdapterUpdated: fileWriteTimer.restart()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            console.log("Failed to load persistent states file:", error);
            if (error == FileViewError.FileNotFound) {
                fileWriteTimer.restart();
            }
        }

        adapter: JsonAdapter {
            id: persistentStatesJsonAdapter

            property string hyprlandInstanceSignature: ""

            property JsonObject idle: JsonObject {
                property bool inhibit: false
            }

            property JsonObject settingsCenter: JsonObject {
                property int width: 1080
                property int height: 720
            }

            property JsonObject display: JsonObject {
                property string optimization: "balanced"
            }

        }
    }
}
