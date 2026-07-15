pragma Singleton
pragma ComponentBehavior: Bound

// Took many bits from https://github.com/caelestia-dots/shell (GPLv3)

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services.network

/**
 * Network service with nmcli.
 *
 * Connect flow:
 *  - known network → try profile up (no password UI first)
 *  - unknown secure network → ask password first, then connect
 *  - open network → connect immediately
 *  - failures that need secrets → re-open password UI with a clear error
 */
Singleton {
    id: root

    property bool wifi: true
    property bool ethernet: false

    property bool wifiEnabled: false
    property bool wifiScanning: false
    property bool wifiConnecting: connectProc.running
    property WifiAccessPoint wifiConnectTarget
    property string wifiConnectPassword: ""
    // idle | connecting | need_password | failed | success
    property string wifiConnectPhase: "idle"
    property string wifiConnectMessage: ""
    property string lastConnectError: ""
    property string connectStderrBuf: ""

    // Active link details (refreshed with update())
    property string primaryDevice: ""
    property string ipv4Address: ""
    property string ipv4Gateway: ""
    property string ipv4Dns: ""
    property string linkBand: ""          // 2.4 GHz / 5 GHz / …
    property string linkFreqMHz: ""
    property string linkTxRate: ""        // e.g. 432.3 MBit/s
    property string linkRxRate: ""
    property string linkSignalDbm: ""
    property string connectionKind: ""    // wifi | ethernet | …

    // All saved Wi-Fi connection profiles (for settings management)
    // [{ name, autoconnect }]
    property var savedWifiProfiles: []

    // Light diagnostics
    // idle | running | done | error
    property string diagPhase: "idle"
    property string diagGatewayMs: ""
    property string diagExternalMs: ""
    property string diagMessage: ""

    // Firewall summary for Advanced
    // unknown | inactive | running | error
    property string firewallState: "unknown"
    property string firewallBackend: ""   // firewalld | ufw | nft | none
    property string firewallDetail: ""

    readonly property list<WifiAccessPoint> wifiNetworks: []
    readonly property WifiAccessPoint active: wifiNetworks.find(n => n.active) ?? null
    property var knownWifiNames: []
    property var wifiAutoconnectByName: ({})
    // Sorted view of wifiNetworks. Recomputed on a debounced timer rather
    // than as a binding that re-sorts the whole list on every AP property
    // change (signal strength updates fire frequently during a scan).
    property list<var> friendlyWifiNetworks: []
    // Cached suggestion list for settings UI (avoid re-sorting in QML bindings).
    property var suggestedWifiList: []
    Timer {
        id: resortTimer
        interval: 300
        repeat: false
        onTriggered: {
            root.friendlyWifiNetworks = [...root.wifiNetworks].sort((a, b) => {
                if (a.active && !b.active)
                    return -1;
                if (!a.active && b.active)
                    return 1;
                return b.strength - a.strength;
            });
            root.suggestedWifiList = root.suggestedSavedNetworks();
        }
    }
    function scheduleResort() {
        resortTimer.restart();
    }
    property string wifiStatus: "disconnected"

    property string networkName: ""
    property int networkStrength
    property string materialSymbol: root.ethernet
        ? "lan"
        : (root.wifiEnabled && root.wifiStatus === "connected")
            ? (
                (root.active?.strength ?? 0) > 83 ? "signal_wifi_4_bar" :
                (root.active?.strength ?? 0) > 67 ? "network_wifi" :
                (root.active?.strength ?? 0) > 50 ? "network_wifi_3_bar" :
                (root.active?.strength ?? 0) > 33 ? "network_wifi_2_bar" :
                (root.active?.strength ?? 0) > 17 ? "network_wifi_1_bar" :
                "signal_wifi_0_bar"
            )
            : (root.wifiStatus === "connecting" || root.wifiConnectPhase === "connecting")
                ? "signal_wifi_statusbar_not_connected"
                : (root.wifiStatus === "disconnected")
                    ? "wifi_find"
                    : (root.wifiStatus === "disabled")
                        ? "signal_wifi_off"
                        : "signal_wifi_bad"

    property string nerdIcon: root.ethernet
        ? "\uDB80\uDC02"
        : (root.wifiEnabled && root.wifiStatus === "connected")
            ? ((root.active?.strength ?? 0) > 83 ? "\uDB82\uDD28"
              : (root.active?.strength ?? 0) > 67 ? "\uDB82\uDD25"
              : (root.active?.strength ?? 0) > 50 ? "\uDB82\uDD22"
              : (root.active?.strength ?? 0) > 33 ? "\uDB82\uDD1F"
              : (root.active?.strength ?? 0) > 17 ? "\uDB82\uDD2F"
              : "\uDB82\uDD2F")
            : (root.wifiStatus === "connecting" || root.wifiConnectPhase === "connecting")
                ? "\uDB82\uDD2E"
                : (root.wifiStatus === "disconnected" || root.wifiStatus === "disabled")
                    ? "\uDB82\uDD2E"
                    : "\uDB82\uDD2E"

    property string cosmicIcon: root.ethernet
        ? "devices/network-wired-symbolic"
        : (root.wifiEnabled && root.wifiStatus === "connected")
            ? (
                (root.active?.strength ?? 0) > 83 ? "status/network-wireless-signal-excellent-symbolic" :
                (root.active?.strength ?? 0) > 67 ? "status/network-wireless-signal-good-symbolic" :
                (root.active?.strength ?? 0) > 50 ? "status/network-wireless-signal-ok-symbolic" :
                (root.active?.strength ?? 0) > 33 ? "status/network-wireless-signal-ok-symbolic" :
                (root.active?.strength ?? 0) > 17 ? "status/network-wireless-signal-weak-symbolic" :
                "status/network-wireless-signal-none-symbolic"
            )
            : (root.wifiStatus === "connecting" || root.wifiConnectPhase === "connecting")
                ? "status/network-wireless-acquiring-symbolic"
                : (root.wifiStatus === "disconnected")
                    ? "status/network-wireless-disconnected-symbolic"
                    : (root.wifiStatus === "disabled")
                        ? "status/network-wireless-disconnected-symbolic"
                        : "status/network-wireless-disconnected-symbolic"

    // ── Helpers ──

    function wifiSecurityRequiresPassword(security: string): bool {
        const s = (security || "").trim().toLowerCase();
        if (s.length === 0 || s === "--" || s === "none" || s === "open" || s === "owe")
            return false;
        return true;
    }

    function isConnectingTo(accessPoint: WifiAccessPoint): bool {
        if (!accessPoint)
            return false;
        return root.wifiConnecting
            && root.wifiConnectTarget
            && root.wifiConnectTarget.ssid === accessPoint.ssid;
    }

    function clearAskingPasswordExcept(keepAp: WifiAccessPoint): void {
        for (let i = 0; i < root.wifiNetworks.length; i++) {
            const n = root.wifiNetworks[i];
            if (n !== keepAp)
                n.askingPassword = false;
        }
    }

    function humanizeConnectError(raw: string): string {
        const t = (raw || "").trim();
        const lower = t.toLowerCase();
        if (lower.includes("secrets were required") || lower.includes("no secrets were provided"))
            return "Password required";
        if (lower.includes("wrong password") || lower.includes("bad password")
                || lower.includes("802-11-wireless-security")
                || lower.includes("authentication")
                || lower.includes("key-mgmt")
                || lower.includes("invalid key")
                || lower.includes("association timed out")
                || lower.includes("failed to add/activate") && lower.includes("secret"))
            return "Password incorrect or rejected";
        if (lower.includes("no network with ssid") || lower.includes("not found")
                || lower.includes("no suitable device") || lower.includes("ssid not found"))
            return "Network not found — try scanning again";
        if (lower.includes("timeout") || lower.includes("timed out"))
            return "Connection timed out";
        if (lower.includes("activation failed") || lower.includes("connection activation failed"))
            return "Activation failed — check password or signal";
        if (lower.includes("device not ready") || lower.includes("unavailable"))
            return "Wi-Fi device not ready";
        if (t.length === 0)
            return "Connection failed";
        // First meaningful line, truncated
        const line = t.split("\n").map(l => l.trim()).find(l => l.length > 0) || t;
        return line.length > 120 ? line.slice(0, 117) + "…" : line;
    }

    function errorLooksLikeSecrets(raw: string): bool {
        const lower = (raw || "").toLowerCase();
        return lower.includes("secrets")
            || lower.includes("password")
            || lower.includes("802-11-wireless-security")
            || lower.includes("key-mgmt")
            || lower.includes("authentication")
            || lower.includes("invalid key")
            || lower.includes("psk");
    }

    // ── Control ──

    function enableWifi(enabled = true): void {
        const cmd = enabled ? "on" : "off";
        enableWifiProc.exec(["nmcli", "radio", "wifi", cmd]);
    }

    function toggleWifi(): void {
        enableWifi(!wifiEnabled);
    }

    function rescanWifi(): void {
        if (!root.wifiEnabled)
            return;
        wifiScanning = true;
        rescanProcess.running = true;
        updateKnownWifiProfiles.running = true;
    }

    function isKnownWifi(accessPoint: WifiAccessPoint): bool {
        return !!accessPoint && root.knownWifiNames.includes(accessPoint.ssid);
    }

    function isWifiAutoconnect(accessPoint: WifiAccessPoint): bool {
        return !!accessPoint && root.wifiAutoconnectByName[accessPoint.ssid] === true;
    }

    function setWifiAutoconnect(accessPoint: WifiAccessPoint, enabled: bool): void {
        if (!accessPoint || !accessPoint.ssid || accessPoint.ssid.length === 0)
            return;
        autoconnectSetProc.exec({
            "environment": {
                "SSID": accessPoint.ssid,
                "AUTOCONNECT": enabled ? "yes" : "no",
                "PRIORITY": enabled ? "50" : "-999"
            },
            "command": ["bash", "-c", 'nmcli connection modify "$SSID" connection.autoconnect "$AUTOCONNECT" connection.autoconnect-priority "$PRIORITY"']
        });
    }

    function markWifiProfileAutoconnect(ssid: string, priority = 50): void {
        if (!ssid || ssid.length === 0)
            return;
        autoconnectProc.exec({
            "environment": {
                "SSID": ssid,
                "PASSWORD": root.wifiConnectPassword,
                "PRIORITY": String(priority)
            },
            "command": ["bash", "-c", 'if [ -n "$PASSWORD" ]; then nmcli connection modify "$SSID" wifi-sec.psk "$PASSWORD" connection.autoconnect yes connection.autoconnect-priority "$PRIORITY" 2>/dev/null; else nmcli connection modify "$SSID" connection.autoconnect yes connection.autoconnect-priority "$PRIORITY" 2>/dev/null; fi; true']
        });
    }

    function connectToWifiNetwork(accessPoint: WifiAccessPoint): void {
        if (!accessPoint || !accessPoint.ssid || accessPoint.ssid.length === 0)
            return;
        if (connectProc.running)
            return;
        if (accessPoint.active)
            return;

        root.clearAskingPasswordExcept(null);
        root.wifiConnectTarget = accessPoint;
        root.wifiConnectPassword = "";
        root.lastConnectError = "";
        root.connectStderrBuf = "";

        if (root.isKnownWifi(accessPoint)) {
            // Saved profile: try without password first.
            accessPoint.askingPassword = false;
            root.wifiConnectPhase = "connecting";
            root.wifiConnectMessage = `Connecting to ${accessPoint.ssid}…`;
            connectProc.exec({
                "environment": { "SSID": accessPoint.ssid },
                "command": ["bash", "-c",
                    'export LANG=C LC_ALL=C; ' +
                    'nmcli -w 25 connection up id "$SSID" 2>&1 ' +
                    '|| nmcli -w 25 device wifi connect "$SSID" 2>&1']
            });
            return;
        }

        if (root.wifiSecurityRequiresPassword(accessPoint.security)) {
            // Unknown secure network: ask for password before attempting.
            accessPoint.askingPassword = true;
            root.wifiConnectPhase = "need_password";
            root.wifiConnectMessage = `Enter password for ${accessPoint.ssid}`;
            return;
        }

        // Open network
        accessPoint.askingPassword = false;
        root.wifiConnectPhase = "connecting";
        root.wifiConnectMessage = `Connecting to ${accessPoint.ssid}…`;
        connectProc.exec({
            "environment": { "SSID": accessPoint.ssid },
            "command": ["bash", "-c",
                'export LANG=C LC_ALL=C; nmcli -w 25 device wifi connect "$SSID" 2>&1']
        });
    }

    function connectToWifiNetworkWithPassword(accessPoint: WifiAccessPoint, password: string): void {
        if (!accessPoint || !accessPoint.ssid || accessPoint.ssid.length === 0)
            return;
        if (connectProc.running)
            return;

        const pw = String(password || "");
        if (pw.length === 0) {
            accessPoint.askingPassword = true;
            root.wifiConnectTarget = accessPoint;
            root.wifiConnectPhase = "need_password";
            root.lastConnectError = "Password is required";
            root.wifiConnectMessage = root.lastConnectError;
            return;
        }
        // WPA-PSK minimum is 8 characters.
        if (pw.length < 8) {
            accessPoint.askingPassword = true;
            root.wifiConnectTarget = accessPoint;
            root.wifiConnectPhase = "need_password";
            root.lastConnectError = "Password must be at least 8 characters";
            root.wifiConnectMessage = root.lastConnectError;
            return;
        }

        root.clearAskingPasswordExcept(accessPoint);
        accessPoint.askingPassword = false;
        root.wifiConnectTarget = accessPoint;
        root.wifiConnectPassword = pw;
        root.lastConnectError = "";
        root.connectStderrBuf = "";
        root.wifiConnectPhase = "connecting";
        root.wifiConnectMessage = `Connecting to ${accessPoint.ssid}…`;

        // If a profile already exists, update PSK then activate it.
        // Otherwise create/join with device wifi connect.
        connectProc.exec({
            "environment": {
                "SSID": accessPoint.ssid,
                "PASSWORD": pw
            },
            "command": ["bash", "-c",
                'export LANG=C LC_ALL=C\n' +
                'if nmcli -t -f NAME connection show 2>/dev/null | grep -Fxq "$SSID"; then\n' +
                '  nmcli connection modify "$SSID" wifi-sec.psk "$PASSWORD" connection.autoconnect yes connection.autoconnect-priority 50 2>&1\n' +
                '  nmcli -w 25 connection up id "$SSID" 2>&1\n' +
                'else\n' +
                '  nmcli -w 25 device wifi connect "$SSID" password "$PASSWORD" 2>&1\n' +
                'fi']
        });
    }

    function cancelWifiPassword(): void {
        if (connectProc.running)
            return;
        if (root.wifiConnectTarget)
            root.wifiConnectTarget.askingPassword = false;
        root.wifiConnectTarget = null;
        root.wifiConnectPassword = "";
        root.wifiConnectPhase = "idle";
        root.wifiConnectMessage = "";
        root.lastConnectError = "";
        root.connectStderrBuf = "";
    }

    function disconnectWifiNetwork(): void {
        if (active)
            disconnectProc.exec(["nmcli", "connection", "down", active.ssid]);
    }

    function disconnectAccessPoint(accessPoint: WifiAccessPoint): void {
        if (accessPoint)
            disconnectProc.exec(["nmcli", "connection", "down", accessPoint.ssid]);
    }

    function forgetWifiNetwork(accessPoint: WifiAccessPoint): void {
        if (accessPoint)
            forgetProc.exec(["nmcli", "connection", "delete", accessPoint.ssid]);
    }

    function forgetSavedProfile(name: string): void {
        if (!name || name.length === 0)
            return;
        forgetProc.exec(["nmcli", "connection", "delete", name]);
    }

    function setSavedProfileAutoconnect(name: string, enabled: bool): void {
        if (!name || name.length === 0)
            return;
        autoconnectSetProc.exec({
            "environment": {
                "SSID": name,
                "AUTOCONNECT": enabled ? "yes" : "no",
                "PRIORITY": enabled ? "50" : "-999"
            },
            "command": ["bash", "-c", 'nmcli connection modify "$SSID" connection.autoconnect "$AUTOCONNECT" connection.autoconnect-priority "$PRIORITY"']
        });
    }

    function openPublicWifiPortal() {
        Quickshell.execDetached(["xdg-open", "https://nmcheck.gnome.org/"])
    }

    function changePassword(network: WifiAccessPoint, password: string, username = ""): void {
        // Prefer the unified password connect path.
        root.connectToWifiNetworkWithPassword(network, password);
    }

    function refreshLinkDetails(): void {
        linkDetailsProc.running = true;
    }

    function refreshSavedProfiles(): void {
        savedProfilesProc.running = true;
    }

    function refreshFirewall(): void {
        firewallProc.running = true;
    }

    function copyConnectionSummary(): void {
        const lines = [
            `Connection: ${root.networkName || root.active?.ssid || "—"}`,
            `Type: ${root.connectionKind || "—"}`,
            `Device: ${root.primaryDevice || "—"}`,
            `IPv4: ${root.ipv4Address || "—"}`,
            `Gateway: ${root.ipv4Gateway || "—"}`,
            `DNS: ${root.ipv4Dns || "—"}`,
            `Band: ${root.linkBand || "—"}`,
            `Freq: ${root.linkFreqMHz || "—"}`,
            `TX rate: ${root.linkTxRate || "—"}`,
            `Signal: ${root.linkSignalDbm || (root.active ? `${root.active.strength}%` : "—")}`
        ].join("\n");
        Quickshell.execDetached([
            "bash", "-c",
            "printf %s " + "'" + lines.replace(/'/g, "'\\''") + "'" + " | wl-copy"
        ]);
    }

    function runLightDiagnostics(): void {
        if (diagProc.running)
            return;
        root.diagPhase = "running";
        root.diagGatewayMs = "";
        root.diagExternalMs = "";
        root.diagMessage = "Checking gateway and internet…";
        diagProc.running = true;
    }

    function suggestedSavedNetworks() {
        // Visible saved APs sorted by strength then prefer 5 GHz name hints.
        const visible = root.friendlyWifiNetworks.filter(ap => root.isKnownWifi(ap) && !ap.active);
        return [...visible].sort((a, b) => {
            const bandBoost = (ap) => {
                const s = (ap.ssid || "").toLowerCase();
                if (s.includes("5g") || s.includes("-5") || s.includes("a-"))
                    return 15;
                if (s.includes("2g") || s.includes("g-"))
                    return -5;
                return 0;
            };
            return (b.strength + bandBoost(b)) - (a.strength + bandBoost(a));
        });
    }

    Process {
        id: enableWifiProc
        onExited: {
            wifiStatusProcess.running = true;
            root.update();
        }
    }

    Process {
        id: connectProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: SplitParser {
            onRead: line => {
                // nmcli often prints errors on stdout when we redirect 2>&1
                if (line && line.length > 0)
                    root.connectStderrBuf += line + "\n";
            }
        }
        stderr: SplitParser {
            onRead: line => {
                if (line && line.length > 0)
                    root.connectStderrBuf += line + "\n";
            }
        }
        onExited: (exitCode, exitStatus) => {
            const target = root.wifiConnectTarget;
            const ssid = target?.ssid ?? "";
            const raw = root.connectStderrBuf;
            getNetworks.running = true;
            updateKnownWifiProfiles.running = true;
            root.update();

            if (exitCode === 0) {
                if (target)
                    target.askingPassword = false;
                root.markWifiProfileAutoconnect(ssid);
                root.wifiConnectPhase = "success";
                root.wifiConnectMessage = ssid.length > 0 ? `Connected to ${ssid}` : "Connected";
                root.lastConnectError = "";
                root.wifiConnectTarget = null;
                root.wifiConnectPassword = "";
                successClearTimer.restart();
                return;
            }

            const msg = root.humanizeConnectError(raw);
            const lower = (raw || "").toLowerCase();
            const notFound = lower.includes("no network")
                || lower.includes("ssid not found")
                || lower.includes("not present")
                || (lower.includes("not found") && lower.includes("ssid"));
            const secrets = root.errorLooksLikeSecrets(raw);
            const activationFail = lower.includes("activation failed")
                || lower.includes("failed to connect")
                || lower.includes("connection activation")
                || lower.includes("device or resource busy");
            const secure = !!(target && root.wifiSecurityRequiresPassword(target.security));
            // Prompt for password when NM asks for secrets, or a secure network fails
            // activation for non-"not found" reasons (often a bad saved PSK).
            const needsSecrets = !notFound && (secrets || (secure && (activationFail || raw.trim().length === 0)));

            if (target && needsSecrets) {
                target.askingPassword = true;
                root.wifiConnectPhase = "need_password";
                root.lastConnectError = msg;
                root.wifiConnectMessage = msg;
                // Keep wifiConnectTarget so the password row stays bound to this AP.
                return;
            }

            if (target)
                target.askingPassword = false;
            root.wifiConnectPhase = "failed";
            root.lastConnectError = msg;
            root.wifiConnectMessage = msg;
            // Keep target briefly so UI can show which network failed.
            failClearTimer.restart();
        }
    }

    Timer {
        id: successClearTimer
        interval: 2500
        repeat: false
        onTriggered: {
            if (root.wifiConnectPhase === "success") {
                root.wifiConnectPhase = "idle";
                root.wifiConnectMessage = "";
            }
        }
    }

    Timer {
        id: failClearTimer
        interval: 6000
        repeat: false
        onTriggered: {
            if (root.wifiConnectPhase === "failed") {
                root.wifiConnectPhase = "idle";
                root.wifiConnectTarget = null;
            }
        }
    }

    Process {
        id: autoconnectProc
        onExited: {
            root.wifiConnectPassword = "";
            updateKnownWifiProfiles.running = true;
        }
    }

    Process {
        id: autoconnectSetProc
        onExited: updateKnownWifiProfiles.running = true
    }

    Process {
        id: disconnectProc
        stdout: SplitParser {
            onRead: getNetworks.running = true
        }
        onExited: {
            getNetworks.running = true;
            root.update();
        }
    }

    Process {
        id: forgetProc
        stdout: SplitParser {
            onRead: getNetworks.running = true
        }
        stderr: SplitParser {
            onRead: getNetworks.running = true
        }
        onExited: {
            getNetworks.running = true;
            updateKnownWifiProfiles.running = true;
            root.refreshSavedProfiles();
            root.update();
        }
    }

    Process {
        id: rescanProcess
        command: ["nmcli", "-w", "15", "dev", "wifi", "list", "--rescan", "yes"]
        onExited: {
            root.wifiScanning = false;
            getNetworks.running = true;
        }
    }

    // Status update
    function update() {
        updateConnectionType.startCheck();
        wifiStatusProcess.running = true
        updateNetworkName.running = true;
        updateNetworkStrength.running = true;
        root.refreshLinkDetails();
        root.refreshSavedProfiles();
    }

    Process {
        id: updateKnownWifiProfiles
        running: true
        command: ["sh", "-c", "export LANG=C LC_ALL=C; nmcli -t -f NAME,TYPE connection show | while IFS=: read -r name type; do [ \"$type\" = \"802-11-wireless\" ] || continue; key=$(nmcli -g 802-11-wireless-security.key-mgmt connection show \"$name\" 2>/dev/null); psk=$(nmcli --show-secrets -g 802-11-wireless-security.psk connection show \"$name\" 2>/dev/null); if [ -z \"$key\" ] || [ -n \"$psk\" ] || [ \"$key\" = \"none\" ]; then auto=$(nmcli -g connection.autoconnect connection show \"$name\" 2>/dev/null); printf '%s\\t%s\\n' \"$name\" \"$auto\"; fi; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const known = [];
                const autoconnect = {};
                for (const line of text.trim().split("\n")) {
                    if (line.length === 0)
                        continue;
                    const parts = line.split("\t");
                    if (parts.length < 2)
                        continue;
                    known.push(parts[0]);
                    autoconnect[parts[0]] = parts[1] === "yes";
                }
                root.knownWifiNames = known;
                root.wifiAutoconnectByName = autoconnect;
            }
        }
    }

    // All wireless profiles (including ones without readable PSK) for the settings list.
    Process {
        id: savedProfilesProc
        running: true
        command: ["sh", "-c", "export LANG=C LC_ALL=C; nmcli -t -f NAME,TYPE,AUTOCONNECT connection show | while IFS=: read -r name type auto; do [ \"$type\" = \"802-11-wireless\" ] || continue; printf '%s\\t%s\\n' \"$name\" \"$auto\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.trim().split("\n")) {
                    if (line.length === 0)
                        continue;
                    const parts = line.split("\t");
                    if (parts.length < 1 || !parts[0])
                        continue;
                    list.push({
                        name: parts[0],
                        autoconnect: parts[1] === "yes"
                    });
                }
                list.sort((a, b) => a.name.localeCompare(b.name));
                root.savedWifiProfiles = list;
            }
        }
    }

    Process {
        id: linkDetailsProc
        running: true
        command: ["bash", "-c", "$HOME/.config/omd/bin/omd-network-link-details"]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.trim().split("\n")) {
                    const idx = line.indexOf("=");
                    if (idx > 0)
                        map[line.slice(0, idx)] = line.slice(idx + 1);
                }
                root.primaryDevice = map.device || "";
                root.connectionKind = map.kind || "";
                root.ipv4Address = map.ip || "";
                root.ipv4Gateway = map.gateway || "";
                root.ipv4Dns = map.dns || "";
                root.linkFreqMHz = map.freq || "";
                root.linkBand = map.band || "";
                root.linkTxRate = map.tx || "";
                root.linkRxRate = map.rx || "";
                root.linkSignalDbm = map.signal || "";
                if (map.conn && map.conn.length > 0 && map.conn !== "--")
                    root.networkName = map.conn;
            }
        }
    }

    Process {
        id: diagProc
        running: false
        command: ["bash", "-c", "$HOME/.config/omd/bin/omd-network-diag"]
        stdout: StdioCollector {
            id: diagCollector
            onStreamFinished: {
                const map = {};
                for (const line of diagCollector.text.trim().split("\n")) {
                    const idx = line.indexOf("=");
                    if (idx > 0)
                        map[line.slice(0, idx)] = line.slice(idx + 1);
                }
                root.diagGatewayMs = map.gateway_ms || "";
                root.diagExternalMs = map.external_ms || "";
            }
        }
        onExited: (code) => {
            const gw = root.diagGatewayMs;
            const ext = root.diagExternalMs;
            const okGw = gw.length > 0 && gw !== "fail" && gw !== "n/a";
            const okExt = ext.length > 0 && ext !== "fail";
            if (okGw && okExt) {
                root.diagPhase = "done";
                root.diagMessage = `Gateway ${gw} ms · Internet ${ext} ms`;
            } else if (okGw && !okExt) {
                root.diagPhase = "done";
                root.diagMessage = `Gateway OK (${gw} ms) · Internet unreachable`;
            } else if (!okGw && okExt) {
                root.diagPhase = "done";
                root.diagMessage = `Gateway issue · Internet ${ext} ms`;
            } else {
                root.diagPhase = "error";
                root.diagMessage = "Could not reach gateway or internet";
            }
        }
    }

    Process {
        id: firewallProc
        running: true
        command: ["bash", "-c", "$HOME/.config/omd/bin/omd-network-firewall"]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.trim().split("\n")) {
                    const idx = line.indexOf("=");
                    if (idx > 0)
                        map[line.slice(0, idx)] = line.slice(idx + 1);
                }
                root.firewallBackend = map.backend || "none";
                root.firewallState = map.state || "unknown";
                root.firewallDetail = map.detail || "";
            }
        }
    }

    Timer {
        id: debounceUpdateTimer
        interval: 2500
        repeat: false
        onTriggered: root.update()
    }

    Process {
        id: subscriber
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: debounceUpdateTimer.restart()
        }
    }

    Process {
        id: updateConnectionType
        property string buffer
        command: ["sh", "-c", "export LANG=C LC_ALL=C; nmcli -t -f TYPE,STATE d status && nmcli -t -f CONNECTIVITY g"]
        running: true
        function startCheck() {
            buffer = "";
            updateConnectionType.running = true;
        }
        stdout: SplitParser {
            onRead: data => {
                updateConnectionType.buffer += data + "\n";
            }
        }
        onExited: (exitCode, exitStatus) => {
            const lines = updateConnectionType.buffer.trim().split('\n');
            const connectivity = lines.pop() // none, limited, full
            let hasEthernet = false;
            let hasWifi = false;
            let wifiStatus = "disconnected";
            lines.forEach(line => {
                if (line.includes("ethernet") && line.includes("connected"))
                    hasEthernet = true;
                else if (line.includes("wifi:")) {
                    if (line.includes("disconnected")) {
                        wifiStatus = "disconnected"
                    }
                    else if (line.includes("connected")) {
                        hasWifi = true;
                        wifiStatus = "connected"

                        if (connectivity === "limited") {
                            hasWifi = false;
                            wifiStatus = "limited"
                        }
                    }
                    else if (line.includes("connecting")) {
                        wifiStatus = "connecting"
                    }
                    else if (line.includes("unavailable")) {
                        wifiStatus = "disabled"
                    }
                }
            });
            root.wifiStatus = wifiStatus;
            root.ethernet = hasEthernet;
            root.wifi = hasWifi;
        }
    }

    Process {
        id: updateNetworkName
        command: ["sh", "-c", "nmcli -t -f NAME c show --active | head -1"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                root.networkName = data;
            }
        }
    }

    Process {
        id: updateNetworkStrength
        running: true
        command: ["sh", "-c", "export LANG=C LC_ALL=C; nmcli -f IN-USE,SIGNAL,SSID device wifi | awk '/^\\*/{if (NR!=1) {print $2}}'"]
        stdout: SplitParser {
            onRead: data => {
                root.networkStrength = parseInt(data);
            }
        }
    }

    Process {
        id: wifiStatusProcess
        command: ["env", "LANG=C", "LC_ALL=C", "nmcli", "radio", "wifi"]
        Component.onCompleted: running = true
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled = text.trim() === "enabled";
            }
        }
    }

    Process {
        id: getNetworks
        running: true
        command: ["env", "LANG=C", "LC_ALL=C", "nmcli", "-g", "ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY", "d", "w"]
        stdout: StdioCollector {
            onStreamFinished: {
                const PLACEHOLDER = "STRINGWHICHHOPEFULLYWONTBEUSED";
                const rep = new RegExp("\\\\:", "g");
                const rep2 = new RegExp(PLACEHOLDER, "g");

                const allNetworks = text.trim().split("\n").map(n => {
                    const net = n.replace(rep, PLACEHOLDER).split(":");
                    return {
                        active: net[0] === "yes",
                        strength: parseInt(net[1]),
                        frequency: parseInt(net[2]),
                        ssid: net[3],
                        bssid: net[4]?.replace(rep2, ":") ?? "",
                        security: net[5] || ""
                    };
                }).filter(n => n.ssid && n.ssid.length > 0);

                // Group networks by SSID and prioritize connected ones
                const networkMap = new Map();
                for (const network of allNetworks) {
                    const existing = networkMap.get(network.ssid);
                    if (!existing) {
                        networkMap.set(network.ssid, network);
                    } else {
                        if (network.active && !existing.active) {
                            networkMap.set(network.ssid, network);
                        } else if (!network.active && !existing.active) {
                            if (network.strength > existing.strength) {
                                networkMap.set(network.ssid, network);
                            }
                        }
                    }
                }

                const wifiNetworks = Array.from(networkMap.values());
                const rNetworks = root.wifiNetworks;

                // Preserve askingPassword / identity across rescans by SSID when possible
                const askingBySsid = {};
                for (const rn of rNetworks) {
                    if (rn.askingPassword)
                        askingBySsid[rn.ssid] = true;
                }

                const destroyed = rNetworks.filter(rn => !wifiNetworks.find(n => n.frequency === rn.frequency && n.ssid === rn.ssid && n.bssid === rn.bssid));
                for (const network of destroyed)
                    rNetworks.splice(rNetworks.indexOf(network), 1).forEach(n => n.destroy());

                for (const network of wifiNetworks) {
                    const match = rNetworks.find(n => n.frequency === network.frequency && n.ssid === network.ssid && n.bssid === network.bssid);
                    if (match) {
                        match.lastIpcObject = network;
                        if (askingBySsid[network.ssid]
                                && root.wifiConnectTarget
                                && root.wifiConnectTarget.ssid === network.ssid)
                            match.askingPassword = true;
                    } else {
                        const obj = apComp.createObject(root, {
                            lastIpcObject: network
                        });
                        if (askingBySsid[network.ssid]
                                && root.wifiConnectTarget
                                && root.wifiConnectTarget.ssid === network.ssid) {
                            obj.askingPassword = true;
                            root.wifiConnectTarget = obj;
                        }
                        rNetworks.push(obj);
                    }
                }
                root.scheduleResort();
            }
        }
    }

    Component {
        id: apComp

        WifiAccessPoint {}
    }
}
