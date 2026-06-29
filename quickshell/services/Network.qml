pragma Singleton
pragma ComponentBehavior: Bound

// Took many bits from https://github.com/caelestia-dots/shell (GPLv3)

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services.network

/**
 * Network service with nmcli.
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
    readonly property list<WifiAccessPoint> wifiNetworks: []
    readonly property WifiAccessPoint active: wifiNetworks.find(n => n.active) ?? null
    property var knownWifiNames: []
    property var wifiAutoconnectByName: ({})
    readonly property list<var> friendlyWifiNetworks: [...wifiNetworks].sort((a, b) => {
        if (a.active && !b.active)
            return -1;
        if (!a.active && b.active)
            return 1;
        return b.strength - a.strength;
    })
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
            : (root.wifiStatus === "connecting")
                ? "signal_wifi_statusbar_not_connected"
                : (root.wifiStatus === "disconnected")
                    ? "wifi_find"
                    : (root.wifiStatus === "disabled")
                        ? "signal_wifi_off"
                        : "signal_wifi_bad"

    property string nerdIcon: root.ethernet
        ? "\uDB80\uDC02"  // mdi-lan U+F0002
        : (root.wifiEnabled && root.wifiStatus === "connected")
            ? ((root.active?.strength ?? 0) > 83 ? "\uDB82\uDD28"   // mdi-wifi-strength-4 U+F0928
              : (root.active?.strength ?? 0) > 67 ? "\uDB82\uDD25"   // mdi-wifi-strength-3 U+F0925
              : (root.active?.strength ?? 0) > 50 ? "\uDB82\uDD22"   // mdi-wifi-strength-2 U+F0922
              : (root.active?.strength ?? 0) > 33 ? "\uDB82\uDD1F"   // mdi-wifi-strength-1 U+F091F
              : (root.active?.strength ?? 0) > 17 ? "\uDB82\uDD2F"   // mdi-wifi-strength-outline U+F092F
              : "\uDB82\uDD2F")                                      // mdi-wifi-strength-outline U+F092F
            : (root.wifiStatus === "connecting")
                ? "\uDB82\uDD2E"  // mdi-wifi-off U+F092E
                : (root.wifiStatus === "disconnected" || root.wifiStatus === "disabled")
                    ? "\uDB82\uDD2E"  // mdi-wifi-off U+F092E
                    : "\uDB82\uDD2E"  // mdi-wifi-off U+F092E

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
            : (root.wifiStatus === "connecting")
                ? "status/network-wireless-acquiring-symbolic"
                : (root.wifiStatus === "disconnected")
                    ? "status/network-wireless-disconnected-symbolic"
                    : (root.wifiStatus === "disabled")
                        ? "status/network-wireless-disconnected-symbolic"
                        : "status/network-wireless-disconnected-symbolic"

    // Control
    function enableWifi(enabled = true): void {
        const cmd = enabled ? "on" : "off";
        enableWifiProc.exec(["nmcli", "radio", "wifi", cmd]);
    }

    function toggleWifi(): void {
        enableWifi(!wifiEnabled);
    }

    function rescanWifi(): void {
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
            "command": ["bash", "-c", 'if [ -n "$PASSWORD" ]; then nmcli connection modify "$SSID" wifi-sec.psk "$PASSWORD" connection.autoconnect yes connection.autoconnect-priority "$PRIORITY"; else nmcli connection modify "$SSID" connection.autoconnect yes connection.autoconnect-priority "$PRIORITY"; fi']
        });
    }

    function connectToWifiNetwork(accessPoint: WifiAccessPoint): void {
        accessPoint.askingPassword = false;
        root.wifiConnectTarget = accessPoint;
        root.wifiConnectPassword = "";
        connectProc.exec({
            "environment": {
                "SSID": accessPoint.ssid
            },
            "command": ["bash", "-c", 'nmcli connection up id "$SSID" || nmcli dev wifi connect "$SSID"']
        });
    }

    function connectToWifiNetworkWithPassword(accessPoint: WifiAccessPoint, password: string): void {
        accessPoint.askingPassword = false;
        root.wifiConnectTarget = accessPoint;
        root.wifiConnectPassword = password;
        connectProc.exec({
            "environment": {
                "SSID": accessPoint.ssid,
                "PASSWORD": password
            },
            "command": ["bash", "-c", 'nmcli dev wifi connect "$SSID" password "$PASSWORD"']
        });
    }

    function disconnectWifiNetwork(): void {
        if (active) disconnectProc.exec(["nmcli", "connection", "down", active.ssid]);
    }

    function disconnectAccessPoint(accessPoint: WifiAccessPoint): void {
        if (accessPoint)
            disconnectProc.exec(["nmcli", "connection", "down", accessPoint.ssid]);
    }

    function forgetWifiNetwork(accessPoint: WifiAccessPoint): void {
        if (accessPoint)
            forgetProc.exec(["nmcli", "connection", "delete", accessPoint.ssid]);
    }

    function openPublicWifiPortal() {
        Quickshell.execDetached(["xdg-open", "https://nmcheck.gnome.org/"]) // From some StackExchange thread, seems to work
    }

    function changePassword(network: WifiAccessPoint, password: string, username = ""): void {
        // TODO: enterprise wifi with username
        network.askingPassword = false;
        changePasswordProc.exec({
            "environment": {
                "PASSWORD": password,
                "SSID": network.ssid
            },
            "command": ["bash", "-c", 'nmcli connection modify "$SSID" wifi-sec.psk "$PASSWORD" connection.autoconnect yes connection.autoconnect-priority 50']
        })
    }

    Process {
        id: enableWifiProc
    }

    Process {
        id: connectProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: SplitParser {
            onRead: line => {
                // print(line)
                getNetworks.running = true
            }
        }
        stderr: SplitParser {
            onRead: line => {
                // print("err:", line)
                if (line.includes("Secrets were required")) {
                    if (root.wifiConnectTarget)
                        root.wifiConnectTarget.askingPassword = true
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            const ssid = root.wifiConnectTarget?.ssid ?? "";
            if (root.wifiConnectTarget)
                root.wifiConnectTarget.askingPassword = (exitCode !== 0)
            if (exitCode === 0)
                root.markWifiProfileAutoconnect(ssid);
            root.wifiConnectTarget = null
            if (exitCode !== 0)
                root.wifiConnectPassword = "";
            updateKnownWifiProfiles.running = true;
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
            update();
        }
    }

    Process {
        id: changePasswordProc
        onExited: { // Re-attempt connection after changing password
            connectProc.running = false
            connectProc.running = true
        }
    }

    Process {
        id: rescanProcess
        command: ["nmcli", "dev", "wifi", "list", "--rescan", "yes"]
        stdout: SplitParser {
            onRead: {
                wifiScanning = false;
                getNetworks.running = true;
            }
        }
    }

    // Status update
    function update() {
        updateConnectionType.startCheck();
        wifiStatusProcess.running = true
        updateNetworkName.running = true;
        updateNetworkStrength.running = true;
        updateKnownWifiProfiles.running = true;
    }

    Process {
        id: updateKnownWifiProfiles
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show | while IFS=: read -r name type; do [ \"$type\" = \"802-11-wireless\" ] || continue; key=$(nmcli -g 802-11-wireless-security.key-mgmt connection show \"$name\" 2>/dev/null); psk=$(nmcli --show-secrets -g 802-11-wireless-security.psk connection show \"$name\" 2>/dev/null); if [ -z \"$key\" ] || [ -n \"$psk\" ]; then auto=$(nmcli -g connection.autoconnect connection show \"$name\" 2>/dev/null); printf '%s\\t%s\\n' \"$name\" \"$auto\"; fi; done"]
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

    Process {
        id: subscriber
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: root.update()
        }
    }

    Process {
        id: updateConnectionType
        property string buffer
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE d status && nmcli -t -f CONNECTIVITY g"]
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
        command: ["sh", "-c", "nmcli -f IN-USE,SIGNAL,SSID device wifi | awk '/^\\*/{if (NR!=1) {print $2}}'"]
        stdout: SplitParser {
            onRead: data => {
                root.networkStrength = parseInt(data);
            }
        }
    }

    Process {
        id: wifiStatusProcess
        command: ["nmcli", "radio", "wifi"]
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
        command: ["nmcli", "-g", "ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY", "d", "w"]
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
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
                        // Prioritize active/connected networks
                        if (network.active && !existing.active) {
                            networkMap.set(network.ssid, network);
                        } else if (!network.active && !existing.active) {
                            // If both are inactive, keep the one with better signal
                            if (network.strength > existing.strength) {
                                networkMap.set(network.ssid, network);
                            }
                        }
                        // If existing is active and new is not, keep existing
                    }
                }

                const wifiNetworks = Array.from(networkMap.values());

                const rNetworks = root.wifiNetworks;

                const destroyed = rNetworks.filter(rn => !wifiNetworks.find(n => n.frequency === rn.frequency && n.ssid === rn.ssid && n.bssid === rn.bssid));
                for (const network of destroyed)
                    rNetworks.splice(rNetworks.indexOf(network), 1).forEach(n => n.destroy());

                for (const network of wifiNetworks) {
                    const match = rNetworks.find(n => n.frequency === network.frequency && n.ssid === network.ssid && n.bssid === network.bssid);
                    if (match) {
                        match.lastIpcObject = network;
                    } else {
                        rNetworks.push(apComp.createObject(root, {
                            lastIpcObject: network
                        }));
                    }
                }
            }
        }
    }

    Component {
        id: apComp

        WifiAccessPoint {}
    }
}
