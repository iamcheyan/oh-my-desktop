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
        setProfileProc.command = ["powerprofilesctl", "set", profile];
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
        command: ["which", "powerprofilesctl"]
        onExited: (exitCode, exitStatus) => {
            root.available = exitCode === 0;
            if (root.available)
                root.refreshAvailableData();
            else {
                root.currentProfile = "unavailable";
                root.profiles = [];
            }
        }
    }

    Process {
        id: getProfileProc
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim();
                if (value.length > 0)
                    root.currentProfile = value;
            }
        }
    }

    Process {
        id: listProfilesProc
        command: ["bash", "-c", "powerprofilesctl list 2>/dev/null | awk '/^\\s*[* ]\\s*[a-zA-Z0-9\\-]+:$/ { gsub(/^[*[:space:]]+|:$/,\"\"); print }' | tac"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.profiles = text.split("\n").map(line => line.trim()).filter(line => line.length > 0);
            }
        }
    }

    Process {
        id: setProfileProc
        onExited: (exitCode, exitStatus) => root.refreshAvailableData()
    }
}
