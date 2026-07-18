import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.settings
import qs.modules.settings.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: pageRoot

    property var settingsRoot: null
    readonly property bool wideLayout: width >= 980
    readonly property string omdRoot: `${FileUtils.trimFileProtocol(Directories.config)}/omd`

    property string optimizationMode: Persistent.ready
        ? (Persistent.states.display?.optimization ?? "balanced")
        : "balanced"

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

    function applyOptimization(mode) {
        if (!Persistent.ready)
            return
        Persistent.states.display.optimization = mode
        pageRoot.optimizationMode = mode

        let evalStr = ""
        if (mode === "performance")
            evalStr = "hl.config({ decoration = { blur = { enabled = false } }, animations = { enabled = false } })"
        else if (mode === "balanced")
            evalStr = "hl.config({ decoration = { blur = { enabled = true, passes = 1 } }, animations = { enabled = true } })"
        else if (mode === "visuals")
            evalStr = "hl.config({ decoration = { blur = { enabled = true, passes = 2 } }, animations = { enabled = true } })"

        if (evalStr !== "")
            Quickshell.execDetached(["hyprctl", "eval", evalStr])
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


    QtObject {
        id: themeState
        property var themes: []
        property string currentSlug: ""
        property string currentName: "Loading…"
        property string currentAccent: SettingsTokens.accent
        property string currentBackground: SettingsTokens.button
        property string currentForeground: SettingsTokens.fg
        property string applyingSlug: ""
        property string message: ""

        function refresh() {
            themeListProc.running = true
            themeCurrentProc.running = true
        }

        function apply(slug) {
            if (!slug || slug.length === 0 || applyingSlug.length > 0)
                return
            applyingSlug = slug
            message = `Applying ${slug}…`
            themeApplyProc.command = [
                "bash", "-c",
                `$HOME/.config/omd/bin/omd-settings-theme apply '${slug.replace(/'/g, "'\\''")}'`
            ]
            themeApplyProc.running = true
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
        columns: pageRoot.wideLayout ? 2 : 1
        columnSpacing: SettingsTokens.columnGap
        rowSpacing: SettingsTokens.columnGap

        // ════════════════════════════════════════
        // LEFT · Themes
        // ════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: pageRoot.wideLayout
                ? (contentGrid.width - SettingsTokens.columnGap) / 2
                : contentGrid.width
            implicitHeight: leftColumn.implicitHeight + SettingsTokens.panelPadding * 2
            radius: SettingsTokens.roundRadius
            color: SettingsTokens.panel
            border.width: 1
            border.color: SettingsTokens.line

            ColumnLayout {
                id: leftColumn
                anchors.fill: parent
                anchors.margins: SettingsTokens.panelPadding
                spacing: SettingsTokens.sectionGap

                // Hero
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 68

                    RowLayout {
                        anchors.fill: parent
                        spacing: 14

                        Rectangle {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            radius: SettingsTokens.radius
                            color: themeState.currentAccent || SettingsTokens.accentSoft
                            border.width: 1
                            border.color: SettingsTokens.line

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "palette"
                                iconSize: 25
                                color: themeState.currentBackground || SettingsTokens.fg
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            StyledText {
                                Layout.fillWidth: true
                                text: "Themes"
                                color: SettingsTokens.fg
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: themeState.applyingSlug.length > 0
                                    ? `Applying ${themeState.applyingSlug}…`
                                    : `${themeState.currentName}  ·  ${themeState.themes.length} available`
                                color: SettingsTokens.muted
                                font.pixelSize: Appearance.font.pixelSize.small
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: SettingsTokens.line
                }

                // Current theme card
                SettingsSection {
                    title: "Current"

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 88
                        radius: SettingsTokens.radius
                        color: themeState.currentBackground || SettingsTokens.button
                        border.width: 1
                        border.color: themeState.currentAccent || SettingsTokens.buttonBorder
                        clip: true

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 6
                            color: themeState.currentAccent || SettingsTokens.accent
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 14
                            anchors.topMargin: 12
                            anchors.bottomMargin: 10
                            spacing: 8

                            StyledText {
                                Layout.fillWidth: true
                                text: themeState.currentName
                                color: themeState.currentForeground || SettingsTokens.fg
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 12
                                radius: 6
                                color: themeState.currentAccent || SettingsTokens.accent
                                border.width: 1
                                border.color: SettingsTokens.buttonBorder
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: themeState.currentSlug
                                color: themeState.currentForeground || SettingsTokens.dim
                                opacity: 0.72
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                elide: Text.ElideRight
                            }
                        }
                    }

                    ButtonRow {
                        SettingsButton {
                            label: "Refresh"
                            iconName: "refresh"
                            onClicked: themeState.refresh()
                        }
                        SettingsButton {
                            label: "Open folder"
                            iconName: "open_in_new"
                            onClicked: Quickshell.execDetached([
                                "xdg-open",
                                `${pageRoot.omdRoot}/current/theme`
                            ])
                        }
                    }

                    StyledText {
                        visible: themeState.message.length > 0
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        text: themeState.message
                        color: SettingsTokens.accent
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                }

                // Theme grid
                SettingsSection {
                    title: "Available"

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        text: "Click a theme to apply. Previews come from colors.toml."
                        color: SettingsTokens.dim
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        wrapMode: Text.WordWrap
                    }

                    Flow {
                        id: themeFlow
                        Layout.fillWidth: true
                        spacing: 10

                        Repeater {
                            model: themeState.themes
                            delegate: Rectangle {
                                required property var modelData

                                width: {
                                    const cols = pageRoot.wideLayout ? 2 : 2
                                    return Math.max(160, Math.floor((themeFlow.width - themeFlow.spacing * (cols - 1)) / cols))
                                }
                                height: 96
                                radius: SettingsTokens.roundRadius
                                color: modelData.background || SettingsTokens.button
                                border.width: modelData.current ? 2 : 1
                                border.color: modelData.current ? SettingsTokens.accent : SettingsTokens.buttonBorder
                                clip: true
                                opacity: themeState.applyingSlug.length > 0
                                    && themeState.applyingSlug !== modelData.slug ? 0.55 : 1

                                Rectangle {
                                    anchors.fill: parent
                                    color: themeMouse.containsMouse ? SettingsTokens.cardHover : "transparent"
                                    opacity: themeMouse.containsMouse ? 0.18 : 0
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 5
                                    color: modelData.accent || SettingsTokens.accent
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 12
                                    anchors.topMargin: 10
                                    anchors.bottomMargin: 8
                                    spacing: 6

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            color: modelData.foreground || SettingsTokens.fg
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }

                                        SettingsStatusPill {
                                            visible: modelData.current || themeState.applyingSlug === modelData.slug
                                            label: themeState.applyingSlug === modelData.slug ? "Applying" : "Current"
                                            active: true
                                        }
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.slug
                                        color: modelData.foreground || SettingsTokens.dim
                                        opacity: 0.62
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 10
                                        radius: 5
                                        color: modelData.accent || SettingsTokens.accent
                                        border.width: 1
                                        border.color: SettingsTokens.buttonBorder
                                    }
                                }

                                MouseArea {
                                    id: themeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: themeState.applyingSlug.length === 0
                                    onClicked: themeState.apply(modelData.slug)
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // ════════════════════════════════════════
        // RIGHT · Wallpaper, font, effects
        // ════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: pageRoot.wideLayout
                ? (contentGrid.width - SettingsTokens.columnGap) / 2
                : contentGrid.width
            implicitHeight: rightColumn.implicitHeight + SettingsTokens.panelPadding * 2
            radius: SettingsTokens.roundRadius
            color: SettingsTokens.panel
            border.width: 1
            border.color: SettingsTokens.line

            ColumnLayout {
                id: rightColumn
                anchors.fill: parent
                anchors.margins: SettingsTokens.panelPadding
                spacing: SettingsTokens.sectionGap

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 40

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 3

                        StyledText {
                            Layout.fillWidth: true
                            text: "Desktop & terminal"
                            color: SettingsTokens.fg
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: wpState.isFolder
                                ? `Folder rotation · every ${wpState.intervalLabel}`
                                : "Wallpaper, font size, and window effects"
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

                // Wallpaper
                SettingsSection {
                    title: "Wallpaper"

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
                            iconName: "skip_next"
                            onClicked: {
                                Quickshell.execDetached(["bash", "-c", "$HOME/.config/omd/bin/omd-wallpaper random"])
                                wpRefreshTimer.restart()
                            }
                        }
                        SettingsButton {
                            label: "Stop rotation"
                            iconName: "stop"
                            onClicked: {
                                Quickshell.execDetached(["bash", "-c", "$HOME/.config/omd/bin/omd-wallpaper stop"])
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
                                'echo "' + Math.round(value) + '" > "$HOME/.local/state/omd/wallpaper/interval" && ' +
                                '$HOME/.config/omd/bin/omd-wallpaper stop && sleep 0.5 && ' +
                                '$HOME/.config/omd/bin/omd-wallpaper random'
                            ])
                            wpRefreshTimer.restart()
                        }
                    }
                }



                // Performance
                SettingsSection {
                    title: "Window effects"

                    ButtonRow {
                        SettingsButton {
                            label: "High perf"
                            iconName: "speed"
                            active: pageRoot.optimizationMode === "performance"
                            onClicked: pageRoot.applyOptimization("performance")
                        }
                        SettingsButton {
                            label: "Balanced"
                            iconName: "balance"
                            active: pageRoot.optimizationMode === "balanced"
                            onClicked: pageRoot.applyOptimization("balanced")
                        }
                        SettingsButton {
                            label: "Visuals"
                            iconName: "palette"
                            active: pageRoot.optimizationMode === "visuals"
                            onClicked: pageRoot.applyOptimization("visuals")
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        text: pageRoot.optimizationMode === "performance"
                            ? "Blur and animations off — smoother UI, less GPU."
                            : pageRoot.optimizationMode === "balanced"
                                ? "One blur pass — good for integrated GPUs."
                                : "Two blur passes — fullest glass look."
                        color: SettingsTokens.dim
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        wrapMode: Text.WordWrap
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

    Timer {
        id: themeMessageTimer
        interval: 3000
        repeat: false
        onTriggered: themeState.message = ""
    }

    Process {
        id: wallpaperStatusProc
        command: ["bash", "-c", "$HOME/.config/omd/bin/omd-wallpaper status 2>/dev/null || true"]
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

    Process {
        id: themeListProc
        command: ["bash", "-c", "$HOME/.config/omd/bin/omd-settings-theme list"]
        running: true
        stdout: StdioCollector {
            id: themeListCollector
            onStreamFinished: {
                const entries = []
                for (const line of themeListCollector.text.trim().split("\n")) {
                    if (line.length === 0)
                        continue
                    const parts = line.split("\t")
                    entries.push({
                        slug: parts[0] || "",
                        name: parts[1] || parts[0] || "",
                        preview: parts[2] || "",
                        current: (parts[3] || "") === "current",
                        accent: parts[4] || "",
                        background: parts[5] || "",
                        foreground: parts[6] || ""
                    })
                }
                themeState.themes = entries
            }
        }
    }

    Process {
        id: themeCurrentProc
        command: ["bash", "-c", "$HOME/.config/omd/bin/omd-settings-theme current"]
        running: true
        stdout: StdioCollector {
            id: themeCurrentCollector
            onStreamFinished: {
                const data = pageRoot.parseKeyValue(themeCurrentCollector.text)
                themeState.currentSlug = data.slug || ""
                themeState.currentName = data.name || "Unknown"
                themeState.currentAccent = data.accent || SettingsTokens.accent
                themeState.currentBackground = data.background || SettingsTokens.button
                themeState.currentForeground = data.foreground || SettingsTokens.fg
            }
        }
    }

    Process {
        id: themeApplyProc
        running: false
        onExited: (exitCode) => {
            OmarchyTheme.reload()
            themeState.applyingSlug = ""
            themeState.message = exitCode === 0 ? "Theme applied" : "Theme apply failed"
            themeMessageTimer.restart()
            themeState.refresh()
        }
    }
}
