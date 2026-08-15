pragma ComponentBehavior: Bound
import qs
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

    readonly property string autostartDir: `${FileUtils.trimFileProtocol(Directories.home)}/.config/autostart`
    property var autostartEntries: []
    property string errorText: ""
    readonly property string rulesFile: `${Directories.root}/hypr/window_rules.lua`
    property var rules: []
    property string defaultBrowser: ""
    property string defaultFileManager: ""
    // labwc sessions have no Hyprland config; hide the Hyprland-only
    // window-rules section (rules are written to hypr/window_rules.lua and
    // applied via hyprctl reload).
    property bool labwcSession: false

    Process {
        command: ["bash", "-c", "echo $XDG_CURRENT_DESKTOP"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: pageRoot.labwcSession = text.trim() === "labwc"
        }
    }

    Component.onCompleted: {
        refreshAutostart()
        refreshRules()
        browserProc.running = true
        fileMgrProc.running = true
    }

            function refreshAutostart() {
                autostartProc.command = ["bash", "-c",
                    'for f in "' + autostartDir + '"/*.desktop "' + autostartDir + '"/*.desktop.disabled; do\n' +
                    '  [ -f "$f" ] || continue\n' +
                    '  base=$(basename "$f")\n' +
                    '  disabled=false\n' +
                    '  case "$base" in *.disabled) disabled=true;; esac\n' +
                    '  name=$(grep -m1 "^Name=" "$f" 2>/dev/null | cut -d= -f2-)\n' +
                    '  [ -z "$name" ] && name=$(echo "$base" | sed "s/\\.desktop.*//")\n' +
                    '  exec=$(grep -m1 "^Exec=" "$f" 2>/dev/null | cut -d= -f2-)\n' +
                    '  echo "$base|$disabled|$name|$exec"\n' +
                    'done']
                autostartProc.running = true
            }

            Process {
                id: autostartProc
                running: false
                stdout: StdioCollector {
                    id: autostartCollector
                    onStreamFinished: {
                        const entries = []
                        for (const line of autostartCollector.text.trim().split('\n')) {
                            if (!line.trim()) continue
                            const parts = line.split('|')
                            if (parts.length < 4) continue
                            entries.push({
                                file: parts[0],
                                disabled: parts[1] === "true",
                                name: parts[2],
                                exec: parts[3],
                            })
                        }
                        entries.sort((a, b) => a.name.localeCompare(b.name))
                        pageRoot.autostartEntries = entries
                    }
                }
            }

            SettingsCard {
                title: "Autostart Applications"
                subtitle: `${pageRoot.autostartEntries.length} entries`

                StyledText {
                    Layout.fillWidth: true
                    text: "Applications that start automatically when you log in."
                    color: SettingsTokens.dim
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.Wrap
                }

                Repeater {
                    model: pageRoot.autostartEntries
                    delegate: Rectangle {
                        id: autoDelegate
                        required property var modelData
                        required property int index
                        readonly property var entry: modelData
                        readonly property bool isEnabled: !entry.disabled

                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        radius: SettingsTokens.radius
                        color: autoMouse.containsMouse ? SettingsTokens.cardHover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            MaterialSymbol {
                                text: autoDelegate.isEnabled ? "play_circle" : "pause_circle"
                                iconSize: 18
                                color: autoDelegate.isEnabled ? SettingsTokens.accent : SettingsTokens.dim
                                Layout.preferredWidth: 22
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                StyledText {
                                    Layout.fillWidth: true
                                    text: autoDelegate.entry.name || "Unknown"
                                    color: SettingsTokens.fg
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: autoDelegate.entry.exec || ""
                                    color: SettingsTokens.dim
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    elide: Text.ElideRight
                                }
                            }

                            // Enable/disable toggle
                            Rectangle {
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 26
                                radius: height / 2
                                color: autoDelegate.isEnabled ? SettingsTokens.accent : "#5a5a5a"

                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: autoDelegate.isEnabled ? parent.width - width - 3 : 3
                                    color: autoDelegate.isEnabled ? "#111111" : "#dedede"
                                    Behavior on x { NumberAnimation { duration: 110 } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        const dir = pageRoot.autostartDir
                                        if (autoDelegate.isEnabled) {
                                            // Disable: rename .desktop → .desktop.disabled
                                            Quickshell.execDetached(["bash", "-c", `mv "${dir}/${autoDelegate.entry.file}" "${dir}/${autoDelegate.entry.file}.disabled" 2>/dev/null`])
                                        } else {
                                            // Enable: rename .desktop.disabled → .desktop
                                            Quickshell.execDetached(["bash", "-c", `mv "${dir}/${autoDelegate.entry.file}" "${dir}/${autoDelegate.entry.file.replace('.disabled', '')}" 2>/dev/null`])
                                        }
                                        autostartRefreshTimer.restart()
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: autoMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }
                    }
                }

                // Empty state
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    visible: pageRoot.autostartEntries.length === 0
                    color: "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: "No autostart entries found in ~/.config/autostart/"
                        color: SettingsTokens.dim
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }

            SettingsCard {
                title: "Add Entry"
                subtitle: "Open autostart folder"

                ButtonRow {
                    SettingsButton {
                        label: "Open Autostart Folder"
                        iconName: "open_in_new"
                        onClicked: { pageRoot.settingsRoot.dismiss(); Quickshell.execDetached(["xdg-open", pageRoot.autostartDir]) }
                    }
                    SettingsButton {
                        label: "Refresh"
                        iconName: "refresh"
                        onClicked: pageRoot.refreshAutostart()
                    }
                }
            }

            Timer {
                id: autostartRefreshTimer
                interval: 500
                repeat: false
                onTriggered: pageRoot.refreshAutostart()
            }

    function refreshRules() {
                rulesProc.command = ["bash", "-c", "cat \"" + rulesFile + "\" 2>/dev/null || echo ''"]
                rulesProc.running = true
            }

            Process {
                id: rulesProc
                running: false
                stdout: StdioCollector {
                    id: rulesCollector
                    onStreamFinished: {
                        const content = rulesCollector.text
                        const entries = []
                        // Parse lines like: o.window("class", { float = true })
                        const regex = /o\.window\(\s*["']([^"']+)["']\s*,\s*\{([^}]*)\}\s*\)/g
                        let match
                        while ((match = regex.exec(content)) !== null) {
                            entries.push({
                                class: match[1],
                                rules: match[2].trim(),
                            })
                        }
                        pageRoot.rules = entries
                    }
                }
            }

            function saveRules() {
                let content = "-- Window rules managed by Sumika Settings Center\n-- Do not edit manually\n\n"
                for (const rule of pageRoot.rules) {
                    content += `o.window("${rule.class}", { ${rule.rules} })\n`
                }
                writeProc.command = ["bash", "-c", `cat > "${pageRoot.rulesFile}" << 'ENDRULES'\n${content}\nENDRULES`]
                writeProc.running = true
            }

            Process {
                id: writeProc
                running: false
                onExited: {
                    // Reload Hyprland config
                    Quickshell.execDetached(["hyprctl", "reload"])
                }
            }

            SettingsCard {
                visible: !pageRoot.labwcSession
                title: "Window Rules"
                subtitle: `${pageRoot.rules.length} rule${pageRoot.rules.length === 1 ? "" : "s"}`

                StyledText {
                    Layout.fillWidth: true
                    text: "Define per-application window rules. Rules are written to hypr/window_rules.lua and applied via hyprctl reload."
                    color: SettingsTokens.dim
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.Wrap
                }

                Repeater {
                    model: pageRoot.rules
                    delegate: Rectangle {
                        id: ruleDelegate
                        required property var modelData
                        required property int index
                        readonly property var rule: modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        radius: SettingsTokens.radius
                        color: ruleMouse.containsMouse ? SettingsTokens.cardHover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            MaterialSymbol {
                                text: "window"
                                iconSize: 18
                                color: SettingsTokens.muted
                                Layout.preferredWidth: 22
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                StyledText {
                                    Layout.fillWidth: true
                                    text: ruleDelegate.rule.class
                                    color: SettingsTokens.fg
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: ruleDelegate.rule.rules
                                    color: SettingsTokens.dim
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    elide: Text.ElideRight
                                }
                            }

                            // Delete button
                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: SettingsTokens.radius
                                color: delMouse.containsMouse ? SettingsTokens.buttonHover : "transparent"

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "delete"
                                    iconSize: 16
                                    color: "#f07070"
                                }

                                MouseArea {
                                    id: delMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        pageRoot.rules.splice(ruleDelegate.index, 1)
                                        pageRoot.rules = pageRoot.rules.slice(0)
                                        pageRoot.saveRules()
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: ruleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }
                    }
                }

                // Empty state
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    visible: pageRoot.rules.length === 0
                    color: "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: "No window rules defined. Add one below."
                        color: SettingsTokens.dim
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }

            // ── Add New Rule ─────────────────────────────────────────────
            SettingsCard {
                id: addRuleCard
                visible: !pageRoot.labwcSession
                title: "Add Rule"
                subtitle: "Define a new window rule"

                property string newClass: ""
                property string newRules: ""

                SettingsTextFieldRow {
                    label: "Application class"
                    description: "Window class to match (e.g. firefox, kitty, org.mozilla.firefox)"
                    text: addRuleCard.newClass
                    onTextEdited: v => addRuleCard.newClass = v
                    placeholder: "class name"
                }

                SettingsTextFieldRow {
                    label: "Rules"
                    description: "Lua table fields (e.g. float = true, opacity = 0.9)"
                    text: addRuleCard.newRules
                    onTextEdited: v => addRuleCard.newRules = v
                    placeholder: "float = true"
                    fieldWidth: 280
                }

                ButtonRow {
                    SettingsButton {
                        label: "Add Rule"
                        iconName: "add"
                        enabledState: addRuleCard.newClass.length > 0
                        onClicked: {
                            if (addRuleCard.newClass.length === 0) return
                            pageRoot.rules.push({
                                class: addRuleCard.newClass,
                                rules: addRuleCard.newRules || "float = true",
                            })
                            pageRoot.rules = pageRoot.rules.slice(0)
                            pageRoot.saveRules()
                            addRuleCard.newClass = ""
                            addRuleCard.newRules = ""
                        }
                    }
                    SettingsButton {
                        label: "Refresh"
                        iconName: "refresh"
                        onClicked: pageRoot.refreshRules()
                    }
                }
            }

            // ── Common Rules Quick Add ───────────────────────────────────
            SettingsCard {
                visible: !pageRoot.labwcSession
                title: "Quick Add"
                subtitle: "Common window rule presets"

                ButtonRow {
                    SettingsButton {
                        label: "Float Terminal"
                        iconName: "picture_in_picture"
                        onClicked: {
                            pageRoot.rules.push({class: "kitty", rules: "float = true"})
                            pageRoot.rules = pageRoot.rules.slice(0)
                            pageRoot.saveRules()
                        }
                    }
                    SettingsButton {
                        label: "Float Firefox"
                        iconName: "picture_in_picture"
                        onClicked: {
                            pageRoot.rules.push({class: "org.mozilla.firefox", rules: "float = true"})
                            pageRoot.rules = pageRoot.rules.slice(0)
                            pageRoot.saveRules()
                        }
                    }
                }
            }

    Process {
                id: browserProc
                command: ["bash", "-c", "xdg-mime query default x-scheme-handler/http 2>/dev/null || echo ''"]
                running: false
                stdout: StdioCollector {
                    id: browserCollector
                    onStreamFinished: pageRoot.defaultBrowser = browserCollector.text.trim()
                }
            }

            Process {
                id: fileMgrProc
                command: ["bash", "-c", "xdg-mime query default inode/directory 2>/dev/null || echo ''"]
                running: false
                stdout: StdioCollector {
                    id: fileMgrCollector
                    onStreamFinished: pageRoot.defaultFileManager = fileMgrCollector.text.trim()
                }
            }

            // ── Default Applications ─────────────────────────────────────
            SettingsCard {
                title: "Default Applications"
                subtitle: "System-wide app preferences"

                SettingsRow {
                    label: "Web browser"
                    description: "Opens http/https links"
                    value: pageRoot.defaultBrowser || "--"
                }

                SettingsRow {
                    label: "File manager"
                    description: "Opens directories"
                    value: pageRoot.defaultFileManager || "--"
                }

                ButtonRow {
                    SettingsButton {
                        label: "Set Default Browser"
                        iconName: "open_in_new"
                        onClicked: { pageRoot.settingsRoot.dismiss(); Quickshell.execDetached(["bash", "-c", "xdg-settings set default-web-browser $(zenity --file-selection --title='Select browser .desktop file' --filename=/usr/share/applications/ --file-filter='Desktop files | *.desktop') 2>/dev/null; true"]) }
                    }
                }
            }

            // ── Sumika App Preferences ───────────────────────────────────
            SettingsCard {
                title: "Sumika App Preferences"
                // Network, Bluetooth, and volume are configured in their dedicated settings pages.
                subtitle: "Commands used by Sumika shortcuts"

                SettingsTextFieldRow {
                    label: "Terminal"
                    description: "Command for opening terminal"
                    text: Config.options.apps.terminal ?? ""
                    onTextEdited: (v) => Config.setNestedValue("apps.terminal", v)
                    placeholder: "kitty -1"
                }

                SettingsTextFieldRow {
                    label: "Task manager"
                    description: "Command for task manager"
                    text: Config.options.apps.taskManager ?? ""
                    onTextEdited: (v) => Config.setNestedValue("apps.taskManager", v)
                    placeholder: "plasma-systemmonitor"
                }
                SettingsTextFieldRow {
                    label: "System update"
                    description: "Command for system updates"
                    text: Config.options.apps.update ?? ""
                    onTextEdited: (v) => Config.setNestedValue("apps.update", v)
                }

                StyledText {
                    Layout.fillWidth: true
                    text: "Network, Bluetooth, and volume mixer are configured in Network & Wireless, Bluetooth, and Sound & Feedback pages."
                    color: SettingsTokens.dim
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }
            }
}
