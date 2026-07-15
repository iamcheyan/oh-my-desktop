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

    required property var settingsRoot
    readonly property bool wideLayout: width >= 980

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

    QtObject {
        id: s

        property string mode: "idle"
        property string lastAction: ""
        property bool pendingInstall: false

        property bool configured: false
        property bool storagePresent: false
        property bool kvm: false
        property bool dockerCli: false
        property bool dockerDaemon: false
        property bool dockerAccess: false
        property bool dockerSocket: false
        property bool dockerGroupMember: false
        property bool compose: false
        property bool freerdp: false
        property string freerdpBin: ""
        property string dockerError: ""
        property string container: "missing"
        property string phase: "not-installed"
        property string progressPercent: ""
        property bool ready: false
        property bool webReachable: false
        property bool rdpReachable: false
        property string web: "http://127.0.0.1:8006"
        property string rdpPort: "3389"
        property string rdpEndpoint: "127.0.0.1:3389"
        property bool rdpPortBusy: false
        property bool rdpPortConflict: false
        property string composeFile: ""
        property string storageDir: ""
        property string sharedDir: ""
        property int storageUsedBytes: 0
        property int diskAvailable: 0
        property int ramTotal: 0
        property int cpuTotal: 0
        property string ram: ""
        property string cpu: ""
        property string disk: ""
        property string user: ""
        property string actionText: ""
        property string actionError: ""

        readonly property bool running: s.container === "running"
        readonly property bool stopped: s.configured && s.container !== "missing" && !s.running
        readonly property bool partial: s.configured && s.container === "missing" && s.storageUsedBytes <= 1048576
        readonly property bool installing: s.mode === "installing" || (s.running && !s.ready)
        readonly property bool fixing: s.mode === "fixing"
        readonly property bool busy: windowsActionProc.running || s.fixing
        readonly property bool hasSystemBlocker: !s.kvm || !s.dockerCli || !s.dockerDaemon || !s.dockerAccess || !s.compose || s.diskAvailable < 74
        readonly property bool showProgress: s.installing || s.fixing || s.mode === "installing"
        readonly property bool needsAttention: s.hasSystemBlocker || s.partial || s.actionError.length > 0

        // Health presentation
        readonly property string healthTitle: {
            if (s.busy && s.mode === "fixing")
                return "Fixing requirements…"
            if (windowsActionProc.running && s.mode === "busy")
                return "Working…"
            if (s.installing || s.mode === "installing")
                return "Installing…"
            if (s.hasSystemBlocker && (!s.configured || s.partial))
                return "Blocked"
            if (!s.configured)
                return "Not installed"
            if (s.partial)
                return "Partial setup"
            if (s.ready)
                return "Ready"
            if (s.running)
                return "Running"
            if (s.stopped)
                return "Stopped"
            return s.phaseText()
        }
        readonly property string healthDetail: {
            if (s.hasSystemBlocker && s.blockerText().length > 0)
                return s.blockerText()
            if (s.ready)
                return `RDP ${s.rdpEndpoint} · web ${s.webReachable ? "up" : "idle"}`
            if (s.installing || s.running)
                return s.phaseText()
            if (s.configured) {
                const bits = []
                if (s.ram.length > 0)
                    bits.push(s.ram)
                if (s.cpu.length > 0)
                    bits.push(`${s.cpu} CPU`)
                if (s.disk.length > 0)
                    bits.push(s.disk)
                return bits.length > 0 ? bits.join(" · ") : s.container
            }
            if (s.diskAvailable > 0)
                return `${s.diskAvailable} GB free · needs ≥ 74 GB`
            return "Dockurr Windows 11 via Docker"
        }
        readonly property string healthIcon: {
            if (s.hasSystemBlocker && (!s.configured || s.partial))
                return "warning"
            if (s.installing || s.fixing || windowsActionProc.running)
                return "hourglass_empty"
            if (s.ready)
                return "desktop_windows"
            if (s.running)
                return "play_circle"
            if (s.stopped)
                return "pause_circle"
            if (s.partial)
                return "build"
            return "desktop_windows"
        }
        readonly property bool healthWarning: {
            if (s.ready)
                return false
            return s.hasSystemBlocker || s.partial || s.actionError.length > 0
        }

        function primaryLabel() {
            if (windowsActionProc.running)
                return "Working…"
            if (s.hasSystemBlocker)
                return "Fix requirements"
            if (!s.configured || s.partial)
                return "Install Windows"
            if (s.ready)
                return "Connect"
            if (s.running && !s.ready)
                return "Open console"
            if (s.stopped)
                return "Start & connect"
            return "Repair / start"
        }
        function primaryIcon() {
            if (windowsActionProc.running)
                return "hourglass_empty"
            if (s.hasSystemBlocker)
                return "build"
            if (!s.configured || s.partial)
                return "download"
            if (s.ready || s.stopped)
                return "open_in_new"
            if (s.running && !s.ready)
                return "open_in_browser"
            return "play_arrow"
        }
        function primaryAction() {
            if (s.hasSystemBlocker) {
                s.beginInstall()
                return
            }
            if (!s.configured || s.partial) {
                s.beginInstall()
                return
            }
            if (s.ready) {
                s.startConnect(false)
                return
            }
            if (s.running && !s.ready) {
                s.run("web")
                return
            }
            if (s.stopped) {
                s.startConnect(false)
                return
            }
            s.beginInstall()
        }
        function statusText() {
            if (!s.configured)
                return "Not installed"
            if (s.ready)
                return "Ready"
            if (s.running)
                return `Running: ${s.phaseText()}`
            if (s.partial)
                return "Partial setup"
            if (s.stopped)
                return "Stopped"
            return s.phaseText()
        }
        function phaseText() {
            if (s.progressPercent.length > 0)
                return `${s.phase} ${s.progressPercent}%`
            return s.phase
        }
        function blockerText() {
            if (!s.kvm)
                return "KVM is unavailable. Enable virtualization in BIOS, then try again."
            if (!s.dockerCli)
                return "Docker is not installed."
            if (!s.dockerAccess)
                return s.dockerError.length > 0 ? s.dockerError : "Current user cannot access Docker."
            if (!s.dockerDaemon)
                return "Docker is installed but the daemon is not running."
            if (!s.compose)
                return "Docker Compose is not installed."
            if (s.diskAvailable < 74)
                return `Only ${s.diskAvailable} GB free. Windows VM needs at least 74 GB.`
            return ""
        }
        function portText() {
            if (s.rdpPortConflict)
                return `Port ${s.rdpPort} is already used; start will switch to a free port.`
            return s.rdpEndpoint
        }
        function formatStorage(bytes) {
            const n = Number(bytes) || 0
            if (n <= 0)
                return "empty"
            if (n < 1024 * 1024)
                return `${n} B`
            if (n < 1024 * 1024 * 1024)
                return `${(n / (1024 * 1024)).toFixed(1)} MB`
            return `${(n / (1024 * 1024 * 1024)).toFixed(1)} GB`
        }
        function reqValue(ok, good, bad) {
            return ok ? good : bad
        }
        function reqColor(ok) {
            return ok ? SettingsTokens.accent : SettingsTokens.danger
        }

        function refresh() {
            if (!windowsStatusProc.running)
                windowsStatusProc.running = true
        }
        function run(action, mode = "busy") {
            s.lastAction = action
            s.mode = mode
            s.actionText = ""
            s.actionError = ""
            windowsActionProc.command = ["bash", "-c", `$HOME/.config/omd/bin/omd-settings-windows-vm ${action}`]
            windowsActionProc.running = true
        }
        function beginInstall() {
            s.pendingInstall = true
            if (s.hasSystemBlocker) {
                s.run("auto-fix", "fixing")
            } else {
                s.run("install-defaults", "installing")
                windowsInstallTimer.running = true
                windowsLogsTimer.running = true
                advancedDisclosure.expanded = true
            }
        }
        function startConnect(keepAlive) {
            pageRoot.settingsRoot.dismiss()
            Quickshell.execDetached([
                "bash", "-c",
                `$HOME/.config/omd/bin/omd-settings-windows-vm ${keepAlive ? "launch-keepalive" : "launch"}`
            ])
        }
        function parseBool(value) {
            return value === "true"
        }
        function applyStatus(d) {
            s.configured = s.parseBool(d.configured)
            s.storagePresent = s.parseBool(d.storagePresent)
            s.kvm = s.parseBool(d.kvm)
            s.dockerCli = s.parseBool(d.dockerCli)
            s.dockerDaemon = s.parseBool(d.dockerDaemon || d.dockerRunning)
            s.dockerAccess = s.parseBool(d.dockerAccess)
            s.dockerSocket = s.parseBool(d.dockerSocket)
            s.dockerGroupMember = s.parseBool(d.dockerGroupMember)
            s.compose = s.parseBool(d.compose)
            s.freerdp = s.parseBool(d.freerdp)
            s.freerdpBin = d.freerdpBin || ""
            s.dockerError = d.dockerError || ""
            s.container = d.container || "missing"
            s.phase = d.phase || "not-installed"
            s.progressPercent = d.progressPercent || ""
            s.ready = s.parseBool(d.ready)
            s.webReachable = s.parseBool(d.webReachable)
            s.rdpReachable = s.parseBool(d.rdpReachable)
            s.web = d.web || "http://127.0.0.1:8006"
            s.rdpPort = d.rdpPort || "3389"
            s.rdpEndpoint = d.rdpEndpoint || `127.0.0.1:${s.rdpPort}`
            s.rdpPortBusy = s.parseBool(d.rdpPortBusy)
            s.rdpPortConflict = s.parseBool(d.rdpPortConflict)
            s.composeFile = d.composeFile || ""
            s.storageDir = d.storageDir || ""
            s.sharedDir = d.sharedDir || ""
            s.storageUsedBytes = parseInt(d.storageUsedBytes || "0")
            s.diskAvailable = parseInt(d.diskAvailable || "0")
            s.ramTotal = parseInt(d.ramTotal || "0")
            s.cpuTotal = parseInt(d.cpuTotal || "0")
            s.ram = d.ram || ""
            s.cpu = d.cpu || ""
            s.disk = d.disk || ""
            s.user = d.user || ""
            if (s.ready && s.mode === "installing") {
                s.mode = "idle"
                windowsInstallTimer.running = false
                windowsLogsTimer.running = false
            }
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
        // LEFT · Status & primary CTA
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
                            color: s.healthWarning ? SettingsTokens.warningPanel : SettingsTokens.accentSoft
                            border.width: s.healthWarning ? 1 : 0
                            border.color: s.healthWarning ? SettingsTokens.warningBorder : "transparent"

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: s.healthIcon
                                iconSize: 25
                                color: s.healthWarning ? SettingsTokens.danger : SettingsTokens.accent
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            StyledText {
                                Layout.fillWidth: true
                                text: "Windows VM"
                                color: SettingsTokens.fg
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: `${s.healthTitle}  ·  ${s.healthDetail}`
                                color: s.healthWarning ? SettingsTokens.danger : SettingsTokens.muted
                                font.pixelSize: Appearance.font.pixelSize.small
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: SettingsTokens.line
                }

                SettingsSection {
                    title: "Primary action"

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        text: {
                            if (s.hasSystemBlocker)
                                return "Resolve host requirements before install or start."
                            if (!s.configured || s.partial)
                                return "Installs Dockurr Windows 11 with sensible defaults (can take a while)."
                            if (s.ready)
                                return "Open a FreeRDP session to the running VM."
                            if (s.running && !s.ready)
                                return "Windows is still setting up — use the web console to watch progress."
                            if (s.stopped)
                                return "Start the container and connect over RDP."
                            return "Repair or start the VM stack."
                        }
                        color: SettingsTokens.dim
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        wrapMode: Text.WordWrap
                    }

                    ButtonRow {
                        SettingsButton {
                            label: s.primaryLabel()
                            iconName: s.primaryIcon()
                            active: s.showProgress || windowsActionProc.running
                            enabledState: !windowsActionProc.running && (s.ready ? s.freerdp : true)
                            onClicked: s.primaryAction()
                        }
                        SettingsButton {
                            label: "Refresh"
                            iconName: "refresh"
                            enabledState: !windowsActionProc.running
                            onClicked: {
                                s.refresh()
                                windowsInstallStatusProc.running = true
                                windowsLogsProc.running = true
                            }
                        }
                    }

                    // Progress panel
                    Rectangle {
                        visible: s.showProgress
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        implicitHeight: progressColumn.implicitHeight + 20
                        radius: SettingsTokens.radius
                        color: SettingsTokens.panelAlt
                        border.width: 1
                        border.color: SettingsTokens.line

                        ColumnLayout {
                            id: progressColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 12
                            spacing: 10

                            StyledText {
                                text: s.mode === "fixing" ? "Fixing requirements" : "Installation progress"
                                color: SettingsTokens.muted
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.DemiBold
                            }

                            StyledProgressBar {
                                Layout.fillWidth: true
                                valueBarHeight: 8
                                indeterminate: true
                                wavy: true
                            }

                            SettingsRow {
                                label: "Phase"
                                value: s.phaseText()
                                clickable: false
                            }
                            SettingsRow {
                                label: "Web console"
                                value: s.webReachable ? "Reachable" : "Not ready"
                                valueColor: s.webReachable ? SettingsTokens.accent : SettingsTokens.muted
                                clickable: false
                            }
                            SettingsRow {
                                label: "RDP"
                                value: s.rdpReachable ? `Reachable · ${s.rdpEndpoint}` : s.portText()
                                valueColor: s.rdpReachable ? SettingsTokens.accent : (s.rdpPortConflict ? SettingsTokens.accent : SettingsTokens.muted)
                                clickable: false
                            }

                            SettingsButton {
                                Layout.fillWidth: true
                                label: "Open console"
                                iconName: "open_in_browser"
                                enabledState: s.webReachable || s.configured
                                onClicked: s.run("web")
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        visible: s.actionText.length > 0
                        text: s.actionText
                        color: SettingsTokens.muted
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        wrapMode: Text.WordWrap
                    }
                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        visible: s.actionError.length > 0
                        text: s.actionError
                        color: SettingsTokens.danger
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        visible: s.ready && !s.freerdp
                        text: "FreeRDP is missing — install xfreerdp or xfreerdp3 to connect from this machine."
                        color: SettingsTokens.accent
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        wrapMode: Text.WordWrap
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // ════════════════════════════════════════
        // RIGHT · Connect & ops
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
                            text: "Connection & ops"
                            color: SettingsTokens.fg
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: s.configured
                                ? `Container ${s.container} · ${s.statusText()}`
                                : "No VM configured yet"
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

                // Connection
                SettingsSection {
                    title: "Connection"

                    SettingsRow {
                        iconName: "language"
                        label: "Web console"
                        description: s.web
                        value: s.webReachable ? "up" : "—"
                        valueColor: s.webReachable ? SettingsTokens.accent : SettingsTokens.muted
                        showChevron: s.configured
                        clickable: s.configured
                        onClicked: s.run("web")
                    }
                    SettingsRow {
                        iconName: "desktop_windows"
                        label: "RDP endpoint"
                        description: s.portText()
                        value: s.rdpReachable ? "up" : (s.rdpPortConflict ? "busy" : "—")
                        valueColor: s.rdpReachable
                            ? SettingsTokens.accent
                            : (s.rdpPortConflict ? SettingsTokens.accent : SettingsTokens.muted)
                        clickable: false
                    }

                    ButtonRow {
                        visible: s.configured
                        SettingsButton {
                            label: "Connect"
                            iconName: "open_in_new"
                            enabledState: s.configured && s.freerdp && !windowsActionProc.running
                            onClicked: s.startConnect(false)
                        }
                        SettingsButton {
                            label: "Keep alive"
                            iconName: "desktop_windows"
                            enabledState: s.configured && s.freerdp && !windowsActionProc.running
                            onClicked: s.startConnect(true)
                        }
                    }

                    ButtonRow {
                        visible: s.configured
                        SettingsButton {
                            label: "Start"
                            iconName: "play_arrow"
                            enabledState: s.configured && !s.running && !windowsActionProc.running
                            onClicked: {
                                s.run("start", "installing")
                                windowsInstallTimer.running = true
                                windowsLogsTimer.running = true
                                advancedDisclosure.expanded = true
                            }
                        }
                        SettingsButton {
                            label: "Stop"
                            iconName: "stop"
                            enabledState: s.configured && s.container !== "missing" && !windowsActionProc.running
                            onClicked: s.run("stop")
                        }
                    }

                    StyledText {
                        visible: !s.configured
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        text: "Connection controls appear after install."
                        color: SettingsTokens.dim
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                }

                // Specs
                SettingsSection {
                    title: "Specs"

                    SettingsRow {
                        label: "RAM"
                        value: s.ram.length > 0 ? s.ram : (s.ramTotal > 0 ? `host ${s.ramTotal} GB` : "--")
                        clickable: false
                    }
                    SettingsRow {
                        label: "CPU"
                        value: s.cpu.length > 0 ? s.cpu : (s.cpuTotal > 0 ? `host ${s.cpuTotal}` : "--")
                        clickable: false
                    }
                    SettingsRow {
                        label: "Disk"
                        value: s.disk.length > 0 ? s.disk : "--"
                        clickable: false
                    }
                    SettingsRow {
                        label: "User"
                        value: s.user.length > 0 ? s.user : "--"
                        clickable: false
                    }
                    SettingsRow {
                        visible: s.sharedDir.length > 0
                        label: "Shared folder"
                        description: s.sharedDir
                        clickable: false
                    }
                }

                // Advanced
                SettingsDisclosure {
                    id: advancedDisclosure
                    title: "Advanced · requirements, paths & logs"
                    expanded: s.hasSystemBlocker || s.showProgress

                    SettingsSection {
                        title: "Requirements"

                        SettingsRow {
                            label: "KVM"
                            value: s.reqValue(s.kvm, "Available", "Missing")
                            valueColor: s.reqColor(s.kvm)
                            clickable: false
                        }
                        SettingsRow {
                            label: "Docker"
                            value: s.dockerAccess
                                ? "Ready"
                                : (s.dockerCli ? "Installed, not usable" : "Missing")
                            valueColor: s.reqColor(s.dockerAccess)
                            clickable: false
                        }
                        SettingsRow {
                            label: "Compose"
                            value: s.reqValue(s.compose, "Available", "Missing")
                            valueColor: s.reqColor(s.compose)
                            clickable: false
                        }
                        SettingsRow {
                            label: "FreeRDP"
                            value: s.freerdp ? s.freerdpBin : "Missing (needed to connect)"
                            valueColor: s.freerdp ? SettingsTokens.accent : SettingsTokens.muted
                            clickable: false
                        }
                        SettingsRow {
                            label: "Free disk"
                            value: `${s.diskAvailable} GB`
                            valueColor: s.diskAvailable >= 74 ? SettingsTokens.accent : SettingsTokens.danger
                            clickable: false
                        }
                        StyledText {
                            Layout.fillWidth: true
                            Layout.leftMargin: 4
                            visible: s.blockerText().length > 0
                            text: s.blockerText()
                            color: SettingsTokens.accent
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            wrapMode: Text.WordWrap
                        }
                    }

                    SettingsSection {
                        title: "Paths"

                        SettingsRow {
                            label: "Compose"
                            description: s.composeFile.length > 0 ? s.composeFile : "--"
                            clickable: false
                        }
                        SettingsRow {
                            label: "Storage"
                            description: s.storageDir.length > 0
                                ? `${s.storageDir} · ${s.formatStorage(s.storageUsedBytes)}`
                                : "--"
                            clickable: false
                        }
                        SettingsRow {
                            label: "Shared"
                            description: s.sharedDir.length > 0 ? s.sharedDir : "--"
                            clickable: false
                        }
                    }

                    SettingsSection {
                        title: "Logs"

                        ButtonRow {
                            SettingsButton {
                                label: "Refresh logs"
                                iconName: "refresh"
                                onClicked: windowsLogsProc.running = true
                            }
                            SettingsButton {
                                label: "Open console"
                                iconName: "open_in_browser"
                                enabledState: s.configured
                                onClicked: s.run("web")
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 200
                            visible: windowsLogsOutput.text.length > 0
                            color: SettingsTokens.panelAlt
                            radius: SettingsTokens.radius
                            border.width: 1
                            border.color: SettingsTokens.line
                            clip: true

                            StyledFlickable {
                                anchors.fill: parent
                                anchors.margins: 8
                                contentHeight: windowsLogsText.height
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: StyledScrollBar {}

                                TextEdit {
                                    id: windowsLogsText
                                    text: windowsLogsOutput.text
                                    color: SettingsTokens.fg
                                    font.family: Appearance.font.family.monospace
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    selectByMouse: true
                                    readOnly: true
                                    wrapMode: TextEdit.Wrap
                                    width: parent.width
                                }
                            }
                        }

                        StyledText {
                            visible: windowsLogsOutput.text.length === 0
                            Layout.fillWidth: true
                            Layout.leftMargin: 4
                            text: "No log output yet. Refresh after install or start."
                            color: SettingsTokens.dim
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                    }

                    SettingsDangerZone {
                        visible: s.configured
                        title: "Remove Windows VM"
                        description: "Stops the container and deletes local VM storage. Shared folder is kept."
                        actionLabel: "Remove"
                        actionIcon: "delete"
                        onActionClicked: s.run("remove --yes")
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    Timer {
        interval: s.installing || s.mode === "installing" ? 5000 : 10000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            s.refresh()
            if (s.installing || s.mode === "installing")
                windowsInstallStatusProc.running = true
        }
    }

    Timer {
        id: windowsInstallTimer
        interval: 5000
        repeat: true
        running: false
        onTriggered: windowsInstallStatusProc.running = true
    }

    Timer {
        id: windowsLogsTimer
        interval: 8000
        repeat: true
        running: false
        onTriggered: windowsLogsProc.running = true
    }

    Process {
        id: windowsStatusProc
        command: ["bash", "-c", "$HOME/.config/omd/bin/omd-settings-windows-vm status"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: s.applyStatus(pageRoot.parseKeyValue(text))
        }
    }

    Process {
        id: windowsInstallStatusProc
        running: false
        command: ["bash", "-c", "$HOME/.config/omd/bin/omd-settings-windows-vm install-status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = pageRoot.parseKeyValue(text)
                if (d.state)
                    s.container = d.state
                if (d.phase)
                    s.phase = d.phase
                s.progressPercent = d.progressPercent || ""
                s.ready = d.ready === "true"
                s.webReachable = d.webReachable === "true"
                s.rdpReachable = d.rdpReachable === "true"
                if (d.rdpPort)
                    s.rdpPort = d.rdpPort
                if (d.rdpEndpoint)
                    s.rdpEndpoint = d.rdpEndpoint
                if (s.ready) {
                    s.mode = "idle"
                    windowsInstallTimer.running = false
                    windowsLogsTimer.running = false
                }
            }
        }
    }

    Process {
        id: windowsLogsProc
        running: false
        command: ["bash", "-c", "$HOME/.config/omd/bin/omd-settings-windows-vm logs"]
        stdout: StdioCollector { id: windowsLogsOutput }
    }

    Process {
        id: windowsActionProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const d = pageRoot.parseKeyValue(text)
                s.actionText = d.progress || d.result || d.log || ""
                s.actionError = d.error || ""
            }
        }
        onExited: (code, status) => {
            s.refresh()
            windowsInstallStatusProc.running = true
            windowsLogsProc.running = true
            if (s.pendingInstall && s.lastAction === "auto-fix") {
                s.pendingInstall = false
                if (code === 0) {
                    s.run("install-defaults", "installing")
                    windowsInstallTimer.running = true
                    windowsLogsTimer.running = true
                    advancedDisclosure.expanded = true
                } else {
                    s.mode = "idle"
                    advancedDisclosure.expanded = true
                }
            } else if (s.lastAction === "install-defaults" || s.lastAction === "start") {
                s.mode = "installing"
                windowsInstallTimer.running = true
                windowsLogsTimer.running = true
                advancedDisclosure.expanded = true
            } else {
                s.mode = "idle"
            }
        }
    }
}
