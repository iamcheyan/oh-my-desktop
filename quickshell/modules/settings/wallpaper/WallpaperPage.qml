import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.settings
import qs.modules.settings.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: pageRoot

    property var settingsRoot: null

    width: parent ? parent.width : 900
    spacing: SettingsTokens.controlGap
    implicitHeight: {
        const viewportHeight = pageRoot.settingsRoot ? pageRoot.settingsRoot.height - 120 : 500
        const contentHeight = contentGrid.implicitHeight + 50 + spacing + 12
        return Math.max(viewportHeight, contentHeight)
    }

    function parseKeyValue(text) {
        const result = {}
        const lines = String(text || "").split("\n")
        for (const line of lines) {
            const idx = line.indexOf("=")
            if (idx > 0)
                result[line.slice(0, idx)] = line.slice(idx + 1)
        }
        return result
    }

    function fileUrl(path) {
        const p = String(path || "").trim()
        if (p.length === 0)
            return ""
        if (p.startsWith("file://"))
            return p
        return "file://" + p
    }

    function shellQuote(value) {
        return "'" + String(value || "").replace(/'/g, "'\\''") + "'"
    }

    function openWallpaperPicker(mode) {
        if (pageRoot.settingsRoot)
            pageRoot.settingsRoot.openWallpaperPicker(mode)
    }

    QtObject {
        id: wpState
        property string mode: "file"
        property string source: ""
        property string current: ""
        property string interval: "3600"
        property int imageCount: 0

        readonly property bool isFolder: mode === "folder"
        readonly property string intervalLabel: {
            const sec = parseInt(interval) || 3600
            if (sec >= 3600)
                return `${Math.round(sec / 3600)}h`
            if (sec >= 60)
                return `${Math.round(sec / 60)}m`
            return `${sec}s`
        }

        function refresh() {
            wallpaperStatusProc.running = true
        }
    }

    Connections {
        target: pageRoot.settingsRoot
        function onWallpaperRefreshNonceChanged() {
            wpRefreshTimer.restart()
        }
    }

    GridLayout {
        id: contentGrid
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: 1
        columnSpacing: SettingsTokens.columnGap
        rowSpacing: SettingsTokens.columnGap

        // ════════════════════════════════════════
        // Wallpaper
        // ════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitHeight: column.implicitHeight + SettingsTokens.panelPadding * 2
            radius: SettingsTokens.roundRadius
            color: SettingsTokens.panel
            border.width: 1
            border.color: SettingsTokens.line

            ColumnLayout {
                id: column
                anchors.fill: parent
                anchors.margins: SettingsTokens.panelPadding
                spacing: SettingsTokens.sectionGap

                // Hero
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 40

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 3

                        StyledText {
                            Layout.fillWidth: true
                            text: "Wallpaper"
                            color: SettingsTokens.fg
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: wpState.isFolder
                                ? `Folder rotation · every ${wpState.intervalLabel}`
                                : "Single image"
                            color: SettingsTokens.muted
                            font.pixelSize: Appearance.font.pixelSize.small
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: SettingsTokens.line
                }

                // Wallpaper section
                SettingsSection {
                    title: "Current wallpaper"

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 90
                            radius: SettingsTokens.radius
                            color: SettingsTokens.button
                            clip: true
                            border.width: 1
                            border.color: SettingsTokens.line

                            Image {
                                id: wallpaperPreview
                                anchors.fill: parent
                                source: pageRoot.fileUrl(wpState.current)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: source.toString().length > 0 && wpState.current.length > 0
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: SettingsTokens.button
                                visible: !wallpaperPreview.visible

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: wpState.isFolder ? "folder" : "image"
                                    iconSize: 32
                                    color: SettingsTokens.dim
                                }
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.margins: 6
                                width: modeBadge.implicitWidth + 14
                                height: 20
                                radius: 10
                                color: wpState.isFolder ? SettingsTokens.accentSoft : SettingsTokens.panelAlt
                                border.width: 1
                                border.color: wpState.isFolder ? SettingsTokens.accent : SettingsTokens.line

                                Row {
                                    id: modeBadge
                                    anchors.centerIn: parent
                                    spacing: 4

                                    MaterialSymbol {
                                        text: wpState.isFolder ? "folder" : "image"
                                        iconSize: 12
                                        color: wpState.isFolder ? SettingsTokens.accent : SettingsTokens.muted
                                    }
                                    StyledText {
                                        text: wpState.isFolder ? "Folder" : "Image"
                                        color: wpState.isFolder ? SettingsTokens.accent : SettingsTokens.muted
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: Font.Medium
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            StyledText {
                                Layout.fillWidth: true
                                text: wpState.source.length > 0
                                    ? FileUtils.fileNameForPath(wpState.source)
                                    : "No wallpaper set"
                                color: SettingsTokens.fg
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: wpState.source.length > 0
                                text: wpState.source
                                color: SettingsTokens.dim
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                elide: Text.ElideRight
                                wrapMode: Text.WrapAnywhere
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: wpState.isFolder && wpState.imageCount > 0
                                text: `${wpState.imageCount} images · every ${wpState.intervalLabel}`
                                color: SettingsTokens.muted
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                        }
                    }

                    ButtonRow {
                        SettingsButton {
                            label: "Choose image"
                            iconName: "image"
                            active: !wpState.isFolder
                            onClicked: {
                                if (pageRoot.settingsRoot)
                                    pageRoot.settingsRoot.openWallpaperPicker("file")
                            }
                        }
                        SettingsButton {
                            label: "Choose folder"
                            iconName: "folder"
                            active: wpState.isFolder
                            onClicked: {
                                if (pageRoot.settingsRoot)
                                    pageRoot.settingsRoot.openWallpaperPicker("folder")
                            }
                        }
                    }

                    ButtonRow {
                        visible: wpState.isFolder
                        SettingsButton {
                            label: "Next image"
                            onClicked: {
                                Quickshell.execDetached(["sumika-wallpaper", "random"])
                                wpRefreshTimer.restart()
                            }
                        }
                        SettingsButton {
                            label: "Stop rotation"
                            onClicked: {
                                Quickshell.execDetached(["sumika-wallpaper", "stop"])
                                wpRefreshTimer.restart()
                            }
                        }
                    }

                    SettingsSliderRow {
                        visible: wpState.isFolder && wpState.imageCount > 0
                        label: "Rotation interval"
                        description: "How often to change the wallpaper"
                        from: 300
                        to: 7200
                        stepSize: 300
                        value: parseInt(wpState.interval) || 3600
                        formatValue: val => wpState.intervalLabel
                        onMoved: {
                            Quickshell.execDetached([
                                "bash", "-c",
                                's="${SUMIKA_SHELL_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/sumika-shell}" && ' +
                                'echo "' + Math.round(value) + '" > "$s/wallpaper/interval" && ' +
                                `sumika-wallpaper restart`
                            ])
                            wpRefreshTimer.restart()
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    // ── Processes / timers ──

    Timer {
        id: wpRefreshTimer
        interval: 1500
        repeat: false
        onTriggered: wpState.refresh()
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: wpState.refresh()
    }

    Process {
        id: wallpaperStatusProc
        command: ["bash", "-c", `sumika-wallpaper status 2>/dev/null || true`]
        running: true
        stdout: StdioCollector {
            id: wallpaperStatusCollector
            onStreamFinished: {
                const data = pageRoot.parseKeyValue(wallpaperStatusCollector.text)
                wpState.mode = data.mode || "file"
                wpState.source = data.source || ""
                wpState.current = data.current || ""
                wpState.interval = data.interval || "3600"
                if (wpState.isFolder && wpState.source.length > 0)
                    wallpaperCountProc.running = true
                else
                    wpState.imageCount = 0
            }
        }
    }

    Process {
        id: wallpaperCountProc
        command: [
            "bash", "-c",
            `find -L '${wpState.source}' -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' \\) 2>/dev/null | wc -l`
        ]
        stdout: StdioCollector {
            id: wallpaperCountCollector
            onStreamFinished: {
                wpState.imageCount = parseInt(wallpaperCountCollector.text.trim()) || 0
            }
        }
    }
}
