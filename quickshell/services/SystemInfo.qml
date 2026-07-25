pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Provides some system info: distro, username.
 */
Singleton {
    id: root
    property string distroName: ""
    property string distroId: "unknown"
    property string distroVersion: ""
    property string distroLike: ""
    property string distroIcon: "linux-symbolic"
    property string username: "user"
    property string homeUrl: ""
    property string documentationUrl: ""
    property string supportUrl: ""
    property string bugReportUrl: ""
    property string privacyPolicyUrl: ""
    property string logo: ""
    property string desktopEnvironment: ""
    property string windowingSystem: ""

    Component.onCompleted: {
        getUsername.running = true
        // FileView auto-loads (running: true) - all distro parsing is in onLoaded
    }

    function parseOsRelease() {
        const textOsRelease = fileOsRelease.text()

        // Name
        const prettyNameMatch = textOsRelease.match(/^PRETTY_NAME="(.+?)"/m)
        const nameMatch = textOsRelease.match(/^NAME="(.+?)"/m)
        root.distroName = prettyNameMatch ? prettyNameMatch[1] : (nameMatch ? nameMatch[1].replace(/Linux/i, "").trim() : "Unknown")

        // Version
        const versionIdMatch = textOsRelease.match(/^VERSION_ID="?(.+?)"?$/m)
        root.distroVersion = versionIdMatch ? versionIdMatch[1] : ""

        // ID_LIKE
        const idLikeMatch = textOsRelease.match(/^ID_LIKE="?(.+?)"?$/m)
        root.distroLike = idLikeMatch ? idLikeMatch[1] : ""

        // ID
        const idMatch = textOsRelease.match(/^ID="?(.+?)"?$/m)
        root.distroId = idMatch ? idMatch[1] : "unknown"

        // URLs & logo
        const homeUrlMatch = textOsRelease.match(/^HOME_URL="(.+?)"/m)
        root.homeUrl = homeUrlMatch ? homeUrlMatch[1] : ""
        const documentationUrlMatch = textOsRelease.match(/^DOCUMENTATION_URL="(.+?)"/m)
        root.documentationUrl = documentationUrlMatch ? documentationUrlMatch[1] : ""
        const supportUrlMatch = textOsRelease.match(/^SUPPORT_URL="(.+?)"/m)
        root.supportUrl = supportUrlMatch ? supportUrlMatch[1] : ""
        const bugReportUrlMatch = textOsRelease.match(/^BUG_REPORT_URL="(.+?)"/m)
        root.bugReportUrl = bugReportUrlMatch ? bugReportUrlMatch[1] : ""
        const privacyPolicyUrlMatch = textOsRelease.match(/^PRIVACY_POLICY_URL="(.+?)"/m)
        root.privacyPolicyUrl = privacyPolicyUrlMatch ? privacyPolicyUrlMatch[1] : ""
        const logoFieldMatch = textOsRelease.match(/^LOGO="?(.+?)"?$/m)
        root.logo = logoFieldMatch ? logoFieldMatch[1] : ""

        // Distro icon
        const iconById = (id) => {
            switch (id) {
                case "artix":
                case "arch": return "arch-symbolic";
                case "endeavouros": return "endeavouros-symbolic";
                case "cachyos": return "cachyos-symbolic";
                case "nixos": return "nixos-symbolic";
                case "fedora": return "fedora-symbolic";
                case "linuxmint":
                case "ubuntu":
                case "zorin":
                case "popos": return "ubuntu-symbolic";
                case "debian":
                case "raspbian":
                case "kali": return "debian-symbolic";
                case "funtoo":
                case "gentoo": return "gentoo-symbolic";
                default: return null;
            }
        };
        root.distroIcon = iconById(root.distroId) ?? "linux-symbolic";

        if (root.distroIcon === "linux-symbolic" && root.distroLike.length > 0) {
            const likes = root.distroLike.split(/\s+/);
            for (let i = 0; i < likes.length; i++) {
                const found = iconById(likes[i]);
                if (found) { root.distroIcon = found; break; }
            }
        }

        if (textOsRelease.toLowerCase().includes("nyarch")) {
            root.distroIcon = "nyarch-symbolic";
        }

        if (root.logo.trim().length === 0) {
            root.logo = root.distroIcon;
        }
    }

    Process {
        id: getUsername
        command: ["whoami"]
        stdout: SplitParser {
            onRead: data => {
                root.username = data.trim()
            }
        }
    }

    Process {
        id: getDesktopEnvironment
        running: true
        command: ["bash", "-c", "echo $XDG_CURRENT_DESKTOP,$WAYLAND_DISPLAY"]
        stdout: StdioCollector {
            id: deCollector
            onStreamFinished: {
                const [desktop, wayland] = deCollector.text.split(",")
                root.desktopEnvironment = desktop.trim()
                root.windowingSystem = wayland.trim().length > 0 ? "Wayland" : "X11" // Are there others? 🤔
            }
        }
    }

    FileView {
        id: fileOsRelease
        path: "/etc/os-release"
        // FileView auto-loads when path is set; parseOsRelease runs in onLoaded.
        onLoaded: root.parseOsRelease()
    }
}