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
    id: page

    required property var settingsRoot

    function parseKeyValue(text) {
        const result = {};
        const lines = String(text || "").split("\\n");
        for (const line of lines) {
            const idx = line.indexOf("=");
            if (idx > 0)
                result[line.slice(0, idx)] = line.slice(idx + 1);
        }
        return result;
    }
    QtObject {
        id: s

        property string mode: "idle"
        property string lastAction: ""
        property bool pendingInstall: false
        property bool removeArmed: false

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
        readonly property bool canInstall: s.kvm && s.dockerAccess && s.compose && s.diskAvailable >= 74
        readonly property bool hasSystemBlocker: !s.kvm || !s.dockerCli || !s.dockerDaemon || !s.dockerAccess || !s.compose || s.diskAvailable < 74

        function refresh() {
            if (!windowsStatusProc.running)
                windowsStatusProc.running = true;
        }
        function run(action, mode = "busy") {
            s.lastAction = action;
            s.mode = mode;
            s.actionText = "";
            s.actionError = "";
            windowsActionProc.command = ["bash", "-c", `$HOME/.config/omd/bin/omd-settings-windows-vm ${action}`];
            windowsActionProc.running = true;
        }
        function beginInstall() {
            s.pendingInstall = true;
            s.removeArmed = false;
            if (s.hasSystemBlocker) {
                s.run("auto-fix", "fixing");
            } else {
                s.run("install-defaults", "installing");
                windowsInstallTimer.running = true;
                windowsLogsTimer.running = true;
            }
        }
        function startConnect(keepAlive) {
            page.settingsRoot.dismiss();
            Quickshell.execDetached([
                "bash", "-c",
                `$HOME/.config/omd/bin/omd-settings-windows-vm ${keepAlive ? "launch-keepalive" : "launch"}`
            ]);
        }
        function primaryLabel() {
            if (windowsActionProc.running) return "Working...";
            if (s.hasSystemBlocker) return "Fix Requirements";
            if (!s.configured || s.partial) return "Install Windows";
            if (!s.ready && s.running) return "Continue Setup";
            return "Repair / Start";
        }
        function statusText() {
            if (!s.configured) return "Not installed";
            if (s.ready) return "Ready";
            if (s.running) return `Running: ${s.phaseText()}`;
            if (s.partial) return "Partial setup";
            if (s.stopped) return "Stopped";
            return s.phaseText();
        }
        function phaseText() {
            if (s.progressPercent.length > 0)
                return `${s.phase} ${s.progressPercent}%`;
            return s.phase;
        }
        function blockerText() {
            if (!s.kvm) return "KVM is unavailable. Enable virtualization in BIOS, then try again.";
            if (!s.dockerCli) return "Docker is not installed.";
            if (!s.dockerAccess) return s.dockerError.length > 0 ? s.dockerError : "Current user cannot access Docker.";
            if (!s.dockerDaemon) return "Docker is installed but the daemon is not running.";
            if (!s.compose) return "Docker Compose is not installed.";
            if (s.diskAvailable < 74) return `Only ${s.diskAvailable} GB free. Windows VM needs at least 74 GB.`;
            return "";
        }
        function portText() {
            if (s.rdpPortConflict) return `Port ${s.rdpPort} is already used; start will switch to a free port.`;
            return s.rdpEndpoint;
        }
        function parseBool(value) { return value === "true"; }
        function applyStatus(d) {
            s.configured = s.parseBool(d.configured);
            s.storagePresent = s.parseBool(d.storagePresent);
            s.kvm = s.parseBool(d.kvm);
            s.dockerCli = s.parseBool(d.dockerCli);
            s.dockerDaemon = s.parseBool(d.dockerDaemon || d.dockerRunning);
            s.dockerAccess = s.parseBool(d.dockerAccess);
            s.dockerSocket = s.parseBool(d.dockerSocket);
            s.dockerGroupMember = s.parseBool(d.dockerGroupMember);
            s.compose = s.parseBool(d.compose);
            s.freerdp = s.parseBool(d.freerdp);
            s.freerdpBin = d.freerdpBin || "";
            s.dockerError = d.dockerError || "";
            s.container = d.container || "missing";
            s.phase = d.phase || "not-installed";
            s.progressPercent = d.progressPercent || "";
            s.ready = s.parseBool(d.ready);
            s.webReachable = s.parseBool(d.webReachable);
            s.rdpReachable = s.parseBool(d.rdpReachable);
            s.web = d.web || "http://127.0.0.1:8006";
            s.rdpPort = d.rdpPort || "3389";
            s.rdpEndpoint = d.rdpEndpoint || `127.0.0.1:${s.rdpPort}`;
            s.rdpPortBusy = s.parseBool(d.rdpPortBusy);
            s.rdpPortConflict = s.parseBool(d.rdpPortConflict);
            s.composeFile = d.composeFile || "";
            s.storageDir = d.storageDir || "";
            s.sharedDir = d.sharedDir || "";
            s.storageUsedBytes = parseInt(d.storageUsedBytes || "0");
            s.diskAvailable = parseInt(d.diskAvailable || "0");
            s.ramTotal = parseInt(d.ramTotal || "0");
            s.cpuTotal = parseInt(d.cpuTotal || "0");
            s.ram = d.ram || "";
            s.cpu = d.cpu || "";
            s.disk = d.disk || "";
            s.user = d.user || "";
            if (s.ready && s.mode === "installing") {
                s.mode = "idle";
                windowsInstallTimer.running = false;
                windowsLogsTimer.running = false;
            }
        }
    }

    SettingsCard {
        title: "Windows VM"
        subtitle: s.statusText()

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            SettingsStatusPill { label: s.ready ? "Ready" : s.running ? "Running" : "Stopped"; active: s.ready || s.running; warning: s.configured && !s.ready && !s.running }
            SettingsStatusPill { label: s.kvm ? "KVM" : "No KVM"; active: s.kvm; warning: !s.kvm }
            SettingsStatusPill { label: s.dockerAccess ? "Docker" : "No Docker"; active: s.dockerAccess; warning: !s.dockerAccess }
            SettingsStatusPill { label: s.freerdp ? "RDP" : "No RDP"; active: s.freerdp; warning: !s.freerdp }
        }

        SettingsRow { label: "Phase"; value: s.phaseText() }
        SettingsRow { label: "Container"; value: s.container; valueColor: s.running ? SettingsTokens.accent : SettingsTokens.muted }
        SettingsRow { label: "Web console"; value: s.web; showChevron: true; onClicked: s.run("web") }
        SettingsRow { label: "RDP endpoint"; value: s.portText(); valueColor: s.rdpPortConflict ? "#f9a825" : SettingsTokens.fg }
        SettingsRow { label: "Storage"; value: s.storageDir.length > 0 ? s.storageDir : "--" }
    }

    SettingsCard {
        visible: s.hasSystemBlocker || !s.freerdp
        title: "System Requirements"
        subtitle: s.hasSystemBlocker ? "Needs attention before install/start" : "Optional client check"

        SettingsRow { label: "KVM"; value: s.kvm ? "Available" : "Missing"; valueColor: s.kvm ? SettingsTokens.accent : "#e53935" }
        SettingsRow { label: "Docker"; value: s.dockerAccess ? "Ready" : s.dockerCli ? "Installed, not usable" : "Missing"; valueColor: s.dockerAccess ? SettingsTokens.accent : "#e53935" }
        SettingsRow { label: "Compose"; value: s.compose ? "Available" : "Missing"; valueColor: s.compose ? SettingsTokens.accent : "#e53935" }
        SettingsRow { label: "FreeRDP"; value: s.freerdp ? s.freerdpBin : "Missing"; valueColor: s.freerdp ? SettingsTokens.accent : "#f9a825" }
        SettingsRow { label: "Free disk"; value: `${s.diskAvailable} GB`; valueColor: s.diskAvailable >= 74 ? SettingsTokens.accent : "#e53935" }

        StyledText {
            Layout.fillWidth: true
            visible: s.blockerText().length > 0
            text: s.blockerText()
            color: "#f9a825"
            font.pixelSize: Appearance.font.pixelSize.smaller
            wrapMode: Text.WordWrap
        }
    }

    SettingsCard {
        title: "Setup"
        subtitle: "Installs Dockurr Windows 11 with sensible defaults"

        ButtonRow {
            SettingsButton {
                label: s.primaryLabel()
                iconName: windowsActionProc.running ? "hourglass" : s.hasSystemBlocker ? "build" : "download"
                active: windowsActionProc.running || s.mode === "installing"
                enabledState: !windowsActionProc.running
                onClicked: s.beginInstall()
            }
            SettingsButton {
                label: "Refresh"
                iconName: "refresh"
                onClicked: { s.refresh(); windowsInstallStatusProc.running = true; windowsLogsProc.running = true; }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: s.actionText.length > 0
            text: s.actionText
            color: SettingsTokens.muted
            font.pixelSize: Appearance.font.pixelSize.smaller
            wrapMode: Text.WordWrap
        }
        StyledText {
            Layout.fillWidth: true
            visible: s.actionError.length > 0
            text: s.actionError
            color: "#e53935"
            font.pixelSize: Appearance.font.pixelSize.smaller
            wrapMode: Text.WordWrap
        }
    }

    SettingsCard {
        visible: s.installing || s.mode === "installing" || s.mode === "fixing"
        title: s.mode === "fixing" ? "Fixing Requirements" : "Installation Progress"
        subtitle: s.mode === "fixing" ? "System permissions may be requested" : "Windows setup can take a while"

        StyledProgressBar {
            Layout.fillWidth: true
            valueBarHeight: 8
            indeterminate: true
            wavy: true
        }

        SettingsRow { label: "Current phase"; value: s.phaseText() }
        SettingsRow { label: "Web console"; value: s.webReachable ? "Reachable" : "Not ready" }
        SettingsRow { label: "RDP"; value: s.rdpReachable ? `Reachable on ${s.rdpEndpoint}` : s.portText() }

        ButtonRow {
            SettingsButton { label: "Open Console"; iconName: "open_in_browser"; enabledState: s.webReachable || s.configured; onClicked: s.run("web") }
            SettingsButton { label: "Refresh Logs"; iconName: "refresh"; onClicked: windowsLogsProc.running = true }
        }
    }

    SettingsCard {
        visible: s.configured
        title: "Manage"
        subtitle: s.ready ? "Connect directly or keep the VM running" : "Start or inspect the VM"

        ButtonRow {
            SettingsButton {
                label: s.ready ? "Connect" : "Start & Connect"
                iconName: "open_in_new"
                enabledState: s.configured && s.freerdp && !windowsActionProc.running
                onClicked: s.startConnect(false)
            }
            SettingsButton {
                label: "Keep Alive"
                iconName: "desktop_windows"
                enabledState: s.configured && s.freerdp && !windowsActionProc.running
                onClicked: s.startConnect(true)
            }
            SettingsButton {
                label: "Start"
                iconName: "play_arrow"
                enabledState: s.configured && !s.running && !windowsActionProc.running
                onClicked: { s.run("start", "installing"); windowsInstallTimer.running = true; windowsLogsTimer.running = true; }
            }
            SettingsButton {
                label: "Stop"
                iconName: "stop"
                enabledState: s.configured && s.container !== "missing" && !windowsActionProc.running
                onClicked: s.run("stop")
            }
        }

        ButtonRow {
            SettingsButton { label: "Open Console"; iconName: "open_in_browser"; enabledState: s.configured; onClicked: s.run("web") }
            SettingsButton {
                label: s.removeArmed ? "Confirm Remove" : "Remove"
                iconName: "delete"
                enabledState: s.configured && !windowsActionProc.running
                onClicked: {
                    if (!s.removeArmed) {
                        s.removeArmed = true;
                        return;
                    }
                    s.run("remove --yes");
                    s.removeArmed = false;
                }
            }
        }

        SettingsRow { label: "RAM"; value: s.ram.length > 0 ? s.ram : "--" }
        SettingsRow { label: "CPU"; value: s.cpu.length > 0 ? s.cpu : "--" }
        SettingsRow { label: "Disk"; value: s.disk.length > 0 ? s.disk : "--" }
        SettingsRow { label: "User"; value: s.user.length > 0 ? s.user : "--" }
        SettingsRow { label: "Shared folder"; value: s.sharedDir.length > 0 ? s.sharedDir : "--" }
    }

    SettingsCard {
        visible: s.configured || windowsLogsOutput.text.length > 0
        title: "Logs"

        ButtonRow {
            SettingsButton { label: "Refresh"; iconName: "refresh"; onClicked: windowsLogsProc.running = true }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 240
            visible: windowsLogsOutput.text.length > 0
            color: SettingsTokens.panelAlt
            radius: 4
            clip: true
            StyledFlickable {
                anchors.fill: parent
                anchors.margins: 4
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
    }

    Timer {
        interval: s.installing || s.mode === "installing" ? 5000 : 10000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            s.refresh();
            if (s.installing || s.mode === "installing")
                windowsInstallStatusProc.running = true;
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
            onStreamFinished: s.applyStatus(page.parseKeyValue(text))
        }
    }

    Process {
        id: windowsInstallStatusProc
        running: false
        command: ["bash", "-c", "$HOME/.config/omd/bin/omd-settings-windows-vm install-status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = page.parseKeyValue(text);
                if (d.state) s.container = d.state;
                if (d.phase) s.phase = d.phase;
                s.progressPercent = d.progressPercent || "";
                s.ready = d.ready === "true";
                s.webReachable = d.webReachable === "true";
                s.rdpReachable = d.rdpReachable === "true";
                if (d.rdpPort) s.rdpPort = d.rdpPort;
                if (d.rdpEndpoint) s.rdpEndpoint = d.rdpEndpoint;
                if (s.ready) {
                    s.mode = "idle";
                    windowsInstallTimer.running = false;
                    windowsLogsTimer.running = false;
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
                const d = page.parseKeyValue(text);
                s.actionText = d.progress || d.result || d.log || "";
                s.actionError = d.error || "";
            }
        }
        onExited: (code, status) => {
            s.refresh();
            windowsInstallStatusProc.running = true;
            windowsLogsProc.running = true;
            if (s.pendingInstall && s.lastAction === "auto-fix") {
                s.pendingInstall = false;
                if (code === 0)
                    s.run("install-defaults", "installing");
            } else if (s.lastAction === "install-defaults" || s.lastAction === "start") {
                s.mode = "installing";
                windowsInstallTimer.running = true;
                windowsLogsTimer.running = true;
            } else {
                s.mode = "idle";
            }
        }
    }
}
