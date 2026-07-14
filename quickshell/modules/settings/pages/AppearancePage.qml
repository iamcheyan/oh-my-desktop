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

PageBody {
    id: pageRoot
    property var settingsRoot: null

    property string optimizationMode: Persistent.ready ? (Persistent.states.display?.optimization ?? "balanced") : "balanced"

    function applyOptimization(mode) {
        if (!Persistent.ready) return;
        Persistent.states.display.optimization = mode;

        let evalStr = "";
        if (mode === "performance") {
            evalStr = "hl.config({ decoration = { blur = { enabled = false } }, animations = { enabled = false } })";
        } else if (mode === "balanced") {
            evalStr = "hl.config({ decoration = { blur = { enabled = true, passes = 1 } }, animations = { enabled = true } })";
        } else if (mode === "visuals") {
            evalStr = "hl.config({ decoration = { blur = { enabled = true, passes = 2 } }, animations = { enabled = true } })";
        }

        if (evalStr !== "") {
            Quickshell.execDetached(["hyprctl", "eval", evalStr]);
        }
    }

    QtObject {
                id: wpState
                property string mode: "file"
                property string source: ""
                property string current: ""
                property string interval: "1800"
                property int imageCount: 0

                readonly property bool isFolder: mode === "folder"
                readonly property string intervalLabel: {
                    const sec = parseInt(interval) || 1800
                    if (sec >= 3600) return `${Math.round(sec / 3600)}h`
                    if (sec >= 60) return `${Math.round(sec / 60)}m`
                    return `${sec}s`
                }

                function refresh() {
                    wallpaperStatusProc.running = true
                }
            }

            Connections {
                target: root
                function onWallpaperRefreshNonceChanged() {
                    wpRefreshTimer.restart()
                }
            }

            SettingsCard {
                title: "Wallpaper"
                subtitle: wpState.isFolder ? "Folder rotation" : "Single image"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 210
                        Layout.preferredHeight: 118
                        radius: SettingsTokens.radius
                        color: SettingsTokens.button
                        clip: true

                        Image {
                            id: wallpaperPreview
                            anchors.fill: parent
                            source: settingsRoot.fileUrl(wpState.current)
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
                                iconSize: 36
                                color: SettingsTokens.dim
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.margins: 6
                            width: modeBadge.implicitWidth + 16
                            height: 22
                            radius: 11
                            color: wpState.isFolder ? SettingsTokens.accentSoft : "#3a3a3a"
                            border.width: 1
                            border.color: wpState.isFolder ? SettingsTokens.accent : "#555"

                            Row {
                                id: modeBadge
                                anchors.centerIn: parent
                                spacing: 4

                                MaterialSymbol {
                                    text: wpState.isFolder ? "folder" : "image"
                                    iconSize: 14
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
                        spacing: 6

                        StyledText {
                            Layout.fillWidth: true
                            text: wpState.source.length > 0 ? FileUtils.fileNameForPath(wpState.source) : "No wallpaper set"
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
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: wpState.isFolder && wpState.imageCount > 0
                            text: `${wpState.imageCount} images · rotates every ${wpState.intervalLabel}`
                            color: SettingsTokens.muted
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                    }
                }

                ButtonRow {
                    SettingsButton {
                        label: "Choose Image"
                        iconName: "image"
                        active: !wpState.isFolder
                        onClicked: settingsRoot.openWallpaperPicker("file")
                    }
                    SettingsButton {
                        label: "Choose Folder"
                        iconName: "folder"
                        active: wpState.isFolder
                        onClicked: settingsRoot.openWallpaperPicker("folder")
                    }
                }

                ButtonRow {
                    visible: wpState.isFolder
                    SettingsButton {
                        label: "Next Image"
                        iconName: "skip_next"
                        onClicked: {
                            Quickshell.execDetached(["bash", "-c", "$HOME/.config/omd/bin/omd-wallpaper random"])
                            wpRefreshTimer.restart()
                        }
                    }
                    SettingsButton {
                        label: "Stop Rotation"
                        iconName: "stop"
                        onClicked: {
                            Quickshell.execDetached(["bash", "-c", "$HOME/.config/omd/bin/omd-wallpaper stop"])
                            wpRefreshTimer.restart()
                        }
                    }
                }

                // Rotation interval slider (folder mode only)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: wpState.isFolder && wpState.imageCount > 0
                    SettingsSliderRow {
                        label: "Rotation interval"
                        description: "How often to rotate the wallpaper"
                        from: 300
                        to: 7200
                        stepSize: 300
                        value: parseInt(wpState.interval) || 1800
                        formatValue: val => wpState.intervalLabel
                        onMoved: {
                            Quickshell.execDetached(["bash", "-c",
                                'echo "' + Math.round(value) + '" > "$HOME/.local/state/omd/wallpaper/interval" && ' +
                                '$HOME/.config/omd/bin/omd-wallpaper stop && sleep 0.5 && ' +
                                '$HOME/.config/omd/bin/omd-wallpaper random'])
                            wpRefreshTimer.restart()
                        }
                    }
                }
            }

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
                command: ["bash", "-c", "$HOME/.config/omd/bin/omd-wallpaper status 2>/dev/null || true"]
                running: true
                stdout: StdioCollector {
                    id: wallpaperStatusCollector
                    onStreamFinished: {
                        const data = settingsRoot.parseKeyValue(wallpaperStatusCollector.text)
                        wpState.mode = data.mode || "file"
                        wpState.source = data.source || ""
                        wpState.current = data.current || ""
                        wpState.interval = data.interval || "1800"
                        if (wpState.isFolder && wpState.source.length > 0) {
                            wallpaperCountProc.running = true
                        } else {
                            wpState.imageCount = 0
                        }
                    }
                }
            }

            Process {
                id: wallpaperCountProc
                command: ["bash", "-c", `find -L '${wpState.source}' -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' \\) 2>/dev/null | wc -l`]
                stdout: StdioCollector {
                    id: wallpaperCountCollector
                    onStreamFinished: {
                        wpState.imageCount = parseInt(wallpaperCountCollector.text.trim()) || 0
                    }
                }
            }

            SettingsCard {
                title: "Terminal Font"
                subtitle: "Font family and size for all terminals"

                SettingsRow {
                    label: "Current font"
                    value: appearanceState.currentFont.length > 0 ? appearanceState.currentFont : "--"
                }

                // Terminal font size slider
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    SettingsSliderRow {
                        label: "Terminal font size"
                        description: "Applies to foot, kitty, alacritty, and ghostty. New windows will use the new size."
                        from: 6
                        to: 24
                        stepSize: 1
                        value: appearanceState.terminalFontSize
                        valueSuffix: "pt"
                        onMoved: appearanceState.terminalFontSize = Math.round(value)
                    }
                }

                ButtonRow {
                    SettingsButton {
                        label: "Apply Now"
                        iconName: "check"
                        onClicked: applyTerminalFontProc.running = true
                    }
                }
            }

            QtObject {
                id: appearanceState
                property string currentTheme: ""
                property string currentFont: ""
                property int terminalFontSize: 9
            }

            Process {
                id: fontSizeReadProc
                command: ["bash", "-c", 'grep -oP "(?<=font_size\\s)\\S+" "$HOME/.config/omd/config/kitty/kitty.conf" 2>/dev/null | head -1 || grep -oP "(?<=size\\s=\\s)\\S+" "$HOME/.config/omd/config/alacritty/alacritty.toml" 2>/dev/null | head -1 || echo 9']
                running: true
                stdout: StdioCollector {
                    id: fontSizeCollector
                    onStreamFinished: {
                        const val = parseFloat(fontSizeCollector.text.trim())
                        if (!isNaN(val) && val > 0)
                            appearanceState.terminalFontSize = Math.round(val)
                    }
                }
            }

            Process {
                id: applyTerminalFontProc
                running: false
                command: ["bash", "-c",
                    'SIZE=' + appearanceState.terminalFontSize + '\n' +
                    '# foot\n' +
                    'sed -i "s/font=\\(.*\\):size=[0-9]*/font=\\1:size=$SIZE/" "$HOME/.config/omd/config/foot/foot.ini" 2>/dev/null\n' +
                    '# kitty\n' +
                    'sed -i "s/font_size\\s.*/font_size $SIZE.0/" "$HOME/.config/omd/config/kitty/kitty.conf" 2>/dev/null\n' +
                    '# alacritty\n' +
                    'sed -i "s/size\\s=\\s[0-9]*/size = $SIZE/" "$HOME/.config/omd/config/alacritty/alacritty.toml" 2>/dev/null\n' +
                    '# ghostty\n' +
                    'sed -i "s/font-size\\s=\\s[0-9]*/font-size = $SIZE/" "$HOME/.config/omd/config/ghostty/config" 2>/dev/null\n' +
                    'true']
                onExited: {
                    fontSizeReadProc.running = true
                }
            }

            Process {
                id: themeCurrentProc
                command: ["bash", "-c", "$HOME/.config/omd/bin/omd-settings-theme current"]
                running: true
                stdout: StdioCollector {
                    id: themeCurrentCollector
                    onStreamFinished: {
                        const data = settingsRoot.parseKeyValue(themeCurrentCollector.text);
                        appearanceState.currentTheme = data.name || "Unknown";
                    }
                }
            }

            Process {
                id: fontCurrentProc
                command: ["bash", "-c", "omd-font-current 2>/dev/null || echo 'JetBrains Mono'"]
                running: true
                stdout: StdioCollector {
                    id: fontCurrentCollector
                    onStreamFinished: {
                        appearanceState.currentFont = fontCurrentCollector.text.trim();
                    }
                }
            }

            QtObject {
                id: themeState
                property var themes: []
                property string currentSlug: ""
                property string currentName: "Loading..."
                property string currentAccent: SettingsTokens.accent
                property string currentBackground: SettingsTokens.button
                property string currentForeground: SettingsTokens.fg
                property string applyingSlug: ""

                function refresh() {
                    themeListProc.running = true;
                    themeCurrentProc2.running = true;
                }

                function apply(slug) {
                    if (!slug || slug.length === 0 || applyingSlug.length > 0)
                        return;
                    applyingSlug = slug;
                    themeApplyProc.command = ["bash", "-c", `$HOME/.config/omd/bin/omd-settings-theme apply '${slug.replace(/'/g, "'\\''")}'`];
                    themeApplyProc.running = true;
                }
            }

            SettingsCard {
                title: "Current Theme"
                subtitle: themeState.currentName

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 18

                    Rectangle {
                        Layout.preferredWidth: 260
                        Layout.preferredHeight: 132
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
                            anchors.leftMargin: 22
                            anchors.rightMargin: 16
                            anchors.topMargin: 16
                            anchors.bottomMargin: 16
                            spacing: 12

                            StyledText {
                                Layout.fillWidth: true
                                text: themeState.currentName
                                color: themeState.currentForeground || SettingsTokens.fg
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Repeater {
                                    model: [themeState.currentAccent || SettingsTokens.accent, themeState.currentForeground || SettingsTokens.fg, themeState.currentBackground || "#000000"]
                                    delegate: Rectangle {
                                        required property string modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 24
                                        radius: 12
                                        color: modelData
                                        border.width: 1
                                        border.color: SettingsTokens.buttonBorder
                                    }
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignBottom
                                text: themeState.currentSlug
                                color: themeState.currentForeground || SettingsTokens.dim
                                opacity: 0.72
                                font.pixelSize: Appearance.font.pixelSize.small
                                elide: Text.ElideRight
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ButtonRow {
                            SettingsButton {
                                label: "Refresh"
                                iconName: "refresh"
                                onClicked: themeState.refresh()
                            }
                            SettingsButton {
                                label: "Open Theme Folder"
                                iconName: "open_in_new"
                                onClicked: Quickshell.execDetached(["xdg-open", `${FileUtils.trimFileProtocol(Directories.config)}/omd/current/theme`])
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: "Theme previews are generated from colors.toml, so themes do not need screenshots."
                            color: SettingsTokens.dim
                            wrapMode: Text.WordWrap
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }
            }

            SettingsCard {
                title: "Available Themes"
                subtitle: `${themeState.themes.length} entries`

                Flow {
                    id: themeFlow
                    Layout.fillWidth: true
                    spacing: 12

                    Repeater {
                        model: themeState.themes
                        delegate: Rectangle {
                            required property var modelData

                            width: Math.max(220, Math.floor((themeFlow.width - themeFlow.spacing) / 2))
                            height: 134
                            radius: SettingsTokens.roundRadius
                            color: modelData.background || SettingsTokens.button
                            border.width: modelData.current ? 2 : 1
                            border.color: modelData.current ? SettingsTokens.accent : SettingsTokens.buttonBorder
                            clip: true

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
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 18
                                anchors.rightMargin: 14
                                anchors.topMargin: 14
                                anchors.bottomMargin: 12
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        color: modelData.foreground || SettingsTokens.fg
                                        font.pixelSize: Appearance.font.pixelSize.normal
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

                                Item {
                                    Layout.fillHeight: true
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Repeater {
                                        model: [modelData.accent || SettingsTokens.accent, modelData.foreground || SettingsTokens.fg, modelData.background || "#000000"]
                                        delegate: Rectangle {
                                            required property string modelData
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 20
                                            radius: 10
                                            color: modelData
                                            border.width: 1
                                            border.color: SettingsTokens.buttonBorder
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: themeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: themeState.apply(modelData.slug)
                            }
                        }
                    }
                }
            }

            Process {
                id: themeListProc
                command: ["bash", "-c", "$HOME/.config/omd/bin/omd-settings-theme list"]
                running: true
                stdout: StdioCollector {
                    id: themeListCollector2
                    onStreamFinished: {
                        const entries = [];
                        for (const line of themeListCollector2.text.trim().split("\n")) {
                            if (line.length === 0) continue;
                            const parts = line.split("\t");
                            entries.push({
                                slug: parts[0] || "",
                                name: parts[1] || parts[0] || "",
                                preview: parts[2] || "",
                                current: (parts[3] || "") === "current",
                                accent: parts[4] || "",
                                background: parts[5] || "",
                                foreground: parts[6] || ""
                            });
                        }
                        themeState.themes = entries;
                    }
                }
            }

            Process {
                id: themeCurrentProc2
                command: ["bash", "-c", "$HOME/.config/omd/bin/omd-settings-theme current"]
                running: true
                stdout: StdioCollector {
                    id: themeCurrentCollector2
                    onStreamFinished: {
                        const data = settingsRoot.parseKeyValue(themeCurrentCollector2.text);
                        themeState.currentSlug = data.slug || "";
                        themeState.currentName = data.name || "Unknown";
                        themeState.currentAccent = data.accent || SettingsTokens.accent;
                        themeState.currentBackground = data.background || SettingsTokens.button;
                        themeState.currentForeground = data.foreground || SettingsTokens.fg;
                    }
                }
            }

            Process {
                id: themeApplyProc
                running: false
                onExited: (exitCode, exitStatus) => {
                    OmarchyTheme.reload();
                    themeState.applyingSlug = "";
                    themeState.refresh();
                }
            }

            SettingsCard {
                title: "Performance & Effects"
                subtitle: pageRoot.optimizationMode === "performance" ? "High Performance" : pageRoot.optimizationMode === "balanced" ? "Balanced" : "Best Visuals"

                ButtonRow {
                    SettingsButton {
                        label: "High Perf"
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
                        label: "Best Visuals"
                        iconName: "palette"
                        active: pageRoot.optimizationMode === "visuals"
                        onClicked: pageRoot.applyOptimization("visuals")
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: pageRoot.optimizationMode === "performance"
                        ? "Frosted glass blur effect is disabled for maximum UI smoothness and battery life."
                        : pageRoot.optimizationMode === "balanced"
                            ? "1 blur pass enabled. High-quality frosted glass look with 50% GPU load reduction (best for integrated GPUs)."
                            : "2 blur passes enabled. Full-resolution premium glass aesthetics (best for dedicated GPUs)."
                    color: SettingsTokens.dim
                    font.pixelSize: Appearance.font.pixelSize.small
                    wrapMode: Text.WordWrap
                }
            }
}
