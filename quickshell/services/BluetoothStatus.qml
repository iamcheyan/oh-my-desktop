pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.functions
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string omdBinDir: (function() {
        var root = Quickshell.env("OMD_REPO_ROOT") || Quickshell.env("OMD_ROOT") || ""
        if (root) return root + "/quickshell/modules/wifi/bin"
        return FileUtils.trimFileProtocol(Directories.root) + "/quickshell/modules/wifi/bin"
    })()
    property bool actionRunning: bluetoothActionProc.running
    property string actionDeviceName: ""
    property string actionAddress: ""
    property string actionStatus: ""
    property string actionMessage: ""
    property string actionPasskey: ""
    property string actionError: ""

    readonly property bool available: Bluetooth.adapters.values.length > 0
    readonly property bool enabled: Bluetooth.defaultAdapter?.enabled ?? false
    readonly property BluetoothDevice firstActiveDevice: Bluetooth.defaultAdapter?.devices.values.find(device => device.connected) ?? null
    readonly property int activeDeviceCount: Bluetooth.defaultAdapter?.devices.values.filter(device => device.connected).length ?? 0
    readonly property bool connected: Bluetooth.devices.values.some(d => d.connected)

    function sortFunction(a, b) {
        // Ones with meaningful names before MAC addresses
        const macRegex = /^([0-9A-Fa-f]{2}-){5}[0-9A-Fa-f]{2}$/;
        const aIsMac = macRegex.test(a.name);
        const bIsMac = macRegex.test(b.name);
        if (aIsMac !== bIsMac)
            return aIsMac ? 1 : -1;

        // Alphabetical by name
        return a.name.localeCompare(b.name);
    }
    property list<var> connectedDevices: Bluetooth.devices.values.filter(d => d.connected).sort(sortFunction)
    property list<var> pairedButNotConnectedDevices: Bluetooth.devices.values.filter(d => d.paired && !d.connected).sort(sortFunction)
    property list<var> unpairedDevices: Bluetooth.devices.values.filter(d => !d.paired && !d.connected).sort(sortFunction)
    property list<var> friendlyDeviceList: [
        ...connectedDevices,
        ...pairedButNotConnectedDevices,
        ...unpairedDevices
    ]

    function deviceAddress(device) {
        const address = device?.address || "";
        if (/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/.test(address))
            return address;
        return "";
    }

    function setActionLine(kind, value) {
        if (kind === "status") {
            actionStatus = value;
            actionMessage = statusMessage(value);
        } else if (kind === "instruction") {
            actionMessage = value;
        } else if (kind === "passkey") {
            actionPasskey = value.trim();
            actionMessage = "Type this code on the Bluetooth keyboard, then press Enter.";
        } else if (kind === "error") {
            actionError = value;
            actionMessage = value;
        }
    }

    function statusMessage(status) {
        if (status === "powering")
            return "Turning Bluetooth on...";
        if (status === "pairing")
            return "Pairing with the device...";
        if (status === "paired")
            return "Pairing accepted.";
        if (status === "trusting")
            return "Trusting the device...";
        if (status === "connecting")
            return "Connecting to the device...";
        if (status === "connected")
            return "Connected.";
        if (status === "disconnecting")
            return "Disconnecting the device...";
        if (status === "removing")
            return "Removing the device...";
        return status;
    }

    function startAction(device, action) {
        const address = deviceAddress(device);
        if (address.length === 0) {
            actionDeviceName = device?.name || device?.deviceName || "Unknown device";
            actionAddress = "";
            actionStatus = "error";
            actionPasskey = "";
            actionError = "Bluetooth device address is unavailable.";
            actionMessage = actionError;
            return;
        }

        actionDeviceName = device?.name || device?.deviceName || address;
        actionAddress = address;
        actionStatus = "starting";
        actionMessage = "Starting Bluetooth action...";
        actionPasskey = "";
        actionError = "";

        if (Bluetooth.defaultAdapter)
            Bluetooth.defaultAdapter.enabled = true;

        bluetoothActionProc.running = false;
        bluetoothActionProc.command = [`${root.omdBinDir}/omd-bluetooth-connect`, address, action];
        bluetoothActionProc.running = true;
    }

    function connectDevice(device) {
        if (device?.connected)
            startAction(device, "disconnect");
        else
            startAction(device, device?.paired ? "connect" : "pair-connect");
    }

    function pairDevice(device) {
        if (device?.paired)
            startAction(device, "forget");
        else
            startAction(device, "pair-connect");
    }

    Process {
        id: bluetoothActionProc
        running: false
        stdout: SplitParser {
            onRead: line => {
                if (!line.startsWith("OMD_BT\t"))
                    return;
                const parts = line.split("\t");
                const kind = parts[1] || "";
                const value = parts.slice(2).join("\t");
                root.setActionLine(kind, value);
            }
        }
        stderr: SplitParser {
            onRead: line => {
                root.actionError = line;
                root.actionMessage = line;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && root.actionError.length === 0) {
                root.actionError = `Bluetooth action failed (${exitCode})`;
                root.actionMessage = root.actionError;
            }
        }
    }
}
