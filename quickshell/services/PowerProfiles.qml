pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool available: false
    property string currentProfile: "unknown"
    property var profiles: []
    property bool setting: setProfileProc.running

    readonly property string dbusDest: "net.hadess.PowerProfiles"
    readonly property string dbusPath: "/net/hadess/PowerProfiles"
    readonly property string dbusIface: "net.hadess.PowerProfiles"

    function refresh() {
        availabilityProc.running = true;
    }

    function refreshAvailableData() {
        if (!available)
            return;
        getProfileProc.running = true;
        listProfilesProc.running = true;
    }

    function setProfile(profile) {
        if (!available || profile === "" || profile === currentProfile)
            return;
        setProfileProc.command = [
            "gdbus", "call", "--system",
            "--dest", root.dbusDest,
            "--object-path", root.dbusPath,
            "--method", "org.freedesktop.DBus.Properties.Set",
            root.dbusIface, "ActiveProfile",
            `<'${profile}'>`
        ];
        setProfileProc.running = true;
    }

    function cycleProfile() {
        if (!available || profiles.length === 0)
            return;
        const index = Math.max(0, profiles.indexOf(currentProfile));
        setProfile(profiles[(index + 1) % profiles.length]);
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 15000
        running: root.available
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: availabilityProc
        command: ["bash", "-c", "gdbus call --system --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles --method org.freedesktop.DBus.Properties.Get net.hadess.PowerProfiles ActiveProfile 2>/dev/null && echo OK || echo FAIL"]
        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                root.available = output.endsWith("OK");
                if (root.available)
                    root.refreshAvailableData();
                else {
                    root.currentProfile = "unavailable";
                    root.profiles = [];
                }
            }
        }
    }

    Process {
        id: getProfileProc
        command: [
            "gdbus", "call", "--system",
            "--dest", root.dbusDest,
            "--object-path", root.dbusPath,
            "--method", "org.freedesktop.DBus.Properties.Get",
            root.dbusIface, "ActiveProfile"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/<'(.*?)'>/);
                if (match)
                    root.currentProfile = match[1];
            }
        }
    }

    Process {
        id: listProfilesProc
        command: [
            "gdbus", "call", "--system",
            "--dest", root.dbusDest,
            "--object-path", root.dbusPath,
            "--method", "org.freedesktop.DBus.Properties.Get",
            root.dbusIface, "Profiles"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const regex = /'Profile': <'(.*?)'/g;
                const result = [];
                let m;
                while ((m = regex.exec(text)) !== null)
                    result.push(m[1]);
                root.profiles = result;
            }
        }
    }

    Process {
        id: setProfileProc
        onExited: (exitCode, exitStatus) => root.refreshAvailableData()
    }
}