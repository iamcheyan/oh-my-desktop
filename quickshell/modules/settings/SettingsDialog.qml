import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Hyprland
import "display" as DisplaySettings
import "wallpaper" as WallpaperSettings
import qs.modules.settings
import qs.modules.settings.widgets
import qs.modules.settings.pages

WindowDialog {
    id: root

    property string requestedPage: "overview"
    property string currentPage: normalizePage(requestedPage)
    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen) ?? ({ brightness: 0, setBrightness: function(){} })
    property int wallpaperRefreshNonce: 0
    property bool keyremapDetailOpen: false
    property string keyremapEditingPreset: ""

    readonly property int shellInset: SettingsTokens.shellInset
    readonly property int pageInset: SettingsTokens.pagePadding
    readonly property int minDialogWidth: 860
    readonly property int minDialogHeight: 560
    readonly property int maxDialogWidth: Math.max(minDialogWidth, width - 32)
    readonly property int maxDialogHeight: Math.max(minDialogHeight, height - 48)
    readonly property int defaultDialogWidth: Math.min(1080, Math.max(920, width - 52))
    readonly property int defaultDialogHeight: Math.min(720, Math.max(600, height - 96))

    readonly property var primaryPages: [
        { key: "overview", icon: "build", title: "OMD Tools", keywords: "tools advanced theme voice keyboard vm" },
        { key: "network", icon: "wifi", title: "Network", keywords: "wifi wireless internet lan ethernet dns firewall connection" },
        { key: "bluetooth", icon: "bluetooth", title: "Bluetooth", keywords: "bluetooth bt device pair connect headset keyboard mouse" },
        { key: "display", icon: "desktop_windows", title: "Displays", keywords: "screen brightness night light monitor resolution refresh scale osd" },
        { key: "appearance", icon: "palette", title: "Appearance", keywords: "theme wallpaper font color look style themes" },
        { key: "power", icon: "battery_charging_full", title: "Power & Battery", keywords: "energy charging profile battery idle sleep" },
        { key: "system", icon: "settings_applications", title: "System", keywords: "autostart startup window rules default apps applications" },
        { key: "keyremap", icon: "keyboard", title: "Keyboard Remap", keywords: "keyboard remap keyd map caps ctrl modifier bluetooth wired device profile" }
    ]

    // Lazy-created Component cache for module settings pages
    property var _modulePageComponents: ({})
    // Maps page key → module settings page entry (includes aliases)
    property var _modulePageEntries: ({})

    readonly property var pages: {
        var ps = []
        var seen = {}
        for (var i = 0; i < primaryPages.length; i++) {
            var pp = primaryPages[i]
            ps.push(pp)
            seen[pp.key] = true
        }
        // Merge module settings pages, skipping duplicates
        var modPages = ModuleLoader.settingsPages
        for (var j = 0; j < modPages.length; j++) {
            var p = modPages[j]
            if (p.id && !seen[p.id]) {
                ps.push({
                    key: p.id,
                    icon: p.icon ?? "extension",
                    title: p.title ?? p.id,
                    keywords: p.keywords ?? ""
                })
                seen[p.id] = true
                // Also mark aliases as seen to prevent collision
                if (p.aliases) {
                    for (var a = 0; a < p.aliases.length; a++) {
                        seen[p.aliases[a]] = true
                    }
                }
            }
        }
        return ps
    }

    function _ensureModulePage(pageId) {
        if (pageId in _modulePageComponents) return
        var modPages = ModuleLoader.settingsPages
        for (var i = 0; i < modPages.length; i++) {
            var p = modPages[i]
            if (!p.id) continue
            if (p.id !== pageId && (!p.aliases || p.aliases.indexOf(pageId) < 0)) continue
            // Found matching module page — create Component lazily
            var comp = Qt.createComponent(p.component)
            if (comp.status === Component.Error) {
                console.warn("[Settings] Failed to load module page:", p.id, comp.errorString())
                return
            }
            _modulePageComponents[p.id] = comp
            _modulePageEntries[p.id] = p
            if (p.aliases) {
                for (var a = 0; a < p.aliases.length; a++) {
                    _modulePageComponents[p.aliases[a]] = comp
                    _modulePageEntries[p.aliases[a]] = p
                }
            }
            return
        }
    }

    function normalizePage(page) {
        if (page === "wifi") return "network";
        if (page === "nightlight") return "display";
        if (page === "audio") return "sound";
        if (page === "battery") return "power";
        if (page === "settings") return "overview";
        if (page === "control") return "overview";
        if (page === "theme") return "appearance";
        if (page === "themes") return "appearance";
        if (page === "font") return "appearance";
        if (page === "wallpaper") return "appearance";
        if (page === "sounds") return "sound";
        if (page === "autostart") return "system";
        if (page === "windowrules") return "system";
        if (page === "apps") return "system";
        if (page === "windows") return "overview";
        if (page === "virtualization") return "overview";
        if (page === "vm") return "overview";
        // Module-managed pages: check aliases before hardcoded redirect
        _ensureModulePage(page)
        if (page in _modulePageEntries) return _modulePageEntries[page].id
        // Hardcoded fallback redirects (non-module pages only)
        if (page === "windows-vm") return "overview";
        if (page === "voice" || page === "voice-input" || page === "speech") return "overview";
        if (page === "keyboard" || page === "keymap" || page === "remap") return "keyremap";
        return page && page.length > 0 ? page : "overview";
    }

    function pageTitle(page) {
        const match = pages.find(item => item.key === page);
        return match ? match.title : "Overview";
    }

    function pageIcon(page) {
        const match = pages.find(item => item.key === page);
        return match ? match.icon : "settings";
    }

    function pageComponent(page) {
        // Pure core pages — always use built-in component
        if (page === "network") return networkPage;
        if (page === "bluetooth") return bluetoothPage;
        if (page === "appearance") return appearancePageComponent;
        if (page === "system") return systemPageComponent;
        // Module-managed pages take priority over core fallbacks
        _ensureModulePage(page)
        if (page in _modulePageComponents) return _modulePageComponents[page]
        // Core fallback for pages that modules CAN provide
        if (page === "display") return migratedDisplayPage;
        if (page === "keyremap") return keyremapPage;
        if (page === "power") return powerPageComponent;
        return overviewPageComponent;
    }

    function clamp(value, min, max) {
        return Math.max(min, Math.min(max, value));
    }

    function shellQuote(value) {
        return "'" + String(value || "").replace(/'/g, "'\\''") + "'";
    }

    function openWallpaperPicker(mode) {
        wallpaperPicker.open(mode);
    }

    onRequestedPageChanged: currentPage = normalizePage(requestedPage)
    onCurrentPageChanged: {}
    onVisibleChanged: {
        if (visible) {
            currentPage = normalizePage(requestedPage);
            root.forceActiveFocus();
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
            root.dismiss();
            event.accepted = true;
        }
    }

    Item {
        id: settingsShell
        Layout.fillWidth: true
        Layout.fillHeight: true

        SettingsPanelFrame {
            anchors.fill: parent
            settingsRoot: root
            title: root.pageTitle(root.currentPage)
            iconName: root.pageIcon(root.currentPage)
            pageComponent: root.pageComponent(root.currentPage)
        }
        // ── Key editor overlay (floating layer for remap-type presets) ──

        KeyboardEditorOverlay {
            anchors.fill: parent
            settingsRoot: root
            visible: root.currentPage === "keyremap" && root.keyremapEditingPreset !== ""
            z: 55
        }

        WallpaperSettings.WallpaperPickerDialog {
            id: wallpaperPicker
            onAccepted: (mode, path) => {
                const action = mode === "folder" ? "set-folder" : "set-file";
                Quickshell.execDetached(["bash", "-lc", `${Directories.root}/bin/omd-wallpaper ` + action + " " + root.shellQuote(path)]);
                root.wallpaperRefreshNonce += 1;
            }
        }
    }



    Component { id: overviewPageComponent; OverviewPage { settingsRoot: root } }
    Component { id: appearancePageComponent; AppearancePage { settingsRoot: root } }

    Component { id: powerPageComponent; PowerPage { settingsRoot: root } }
    Component { id: systemPageComponent; SystemPage { settingsRoot: root } }

    Component {
        id: migratedDisplayPage
        DisplaySettings.DisplayPage {
            brightnessMonitor: root.brightnessMonitor
            settingsRoot: root
        }
    }

    Component {
        id: networkPage
        NetworkPage {
            settingsRoot: root
            mode: root.currentPage
        }
    }

    Component { id: bluetoothPage; BluetoothPage { settingsRoot: root } }

    Component { id: keyremapPage; KeyboardRemapPage { settingsRoot: root } }

}
