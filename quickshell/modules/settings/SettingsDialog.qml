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
import Quickshell.Services.Pipewire
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
    property bool keyremapApplyConfirmOpen: false
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
        { key: "network", icon: "wifi", title: "Devices & Connection", keywords: "wifi wireless bluetooth internet lan device connection" },
        { key: "bluetooth", icon: "bluetooth", title: "Bluetooth", keywords: "bluetooth device pairing wireless" },
        { key: "sound", icon: "volume_up", title: "Sound & Feedback", keywords: "audio volume mute speaker microphone input output sounds feedback osd" },
        { key: "display", icon: "desktop_windows", title: "Displays", keywords: "screen brightness night light monitor resolution refresh scale osd" },
        { key: "appearance", icon: "palette", title: "Appearance", keywords: "theme wallpaper font color look style themes" },
        { key: "power", icon: "battery_charging_full", title: "Power & Battery", keywords: "energy charging profile battery idle sleep" },
        { key: "system", icon: "settings_applications", title: "System", keywords: "autostart startup window rules default apps applications" },
        { key: "voice", icon: "keyboard_voice", title: "Voice Input", keywords: "speech transcribe sherpa microphone dictation record model keybinding diagnostic" },
        { key: "keyremap", icon: "keyboard", title: "Keyboard Remap", keywords: "keyboard remap keyd map caps ctrl modifier bluetooth wired device profile" },
        { key: "windows", icon: "desktop_windows", title: "Windows VM", keywords: "virtualization virtual machine vm docker kvm rdp windows" }
    ]

    readonly property var pages: primaryPages


    backgroundWidth: clamp(Persistent.states.settingsCenter.width || defaultDialogWidth, minDialogWidth, maxDialogWidth)
    backgroundHeight: clamp(Persistent.states.settingsCenter.height || defaultDialogHeight, minDialogHeight, maxDialogHeight)
    anchorPosition: 0
    contentPadding: 0
    dismissOnBackgroundPress: false

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
        if (page === "virtualization") return "windows";
        if (page === "vm") return "windows";
        if (page === "windows-vm") return "windows";
        if (page === "voice") return "voice";
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
        if (page === "network" || page === "bluetooth") return networkPage;
        if (page === "display") return migratedDisplayPage;
        if (page === "voice") return voicePage;
        if (page === "keyremap") return keyremapPage;
        if (page === "windows") return windowsPage;
        if (page === "appearance") return appearancePageComponent;
        if (page === "sound") return soundPageComponent;
        if (page === "power") return powerPageComponent;
        if (page === "system") return systemPageComponent;
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
            anchors.fill: parent
            onAccepted: (mode, path) => {
                const action = mode === "folder" ? "set-folder" : "set-file";
                Quickshell.execDetached(["bash", "-lc", "$HOME/.config/omd/bin/omd-wallpaper " + action + " " + root.shellQuote(path)]);
                root.wallpaperRefreshNonce += 1;
            }
        }
    }



    Component { id: overviewPageComponent; OverviewPage { settingsRoot: root } }
    Component { id: appearancePageComponent; AppearancePage { settingsRoot: root } }
    Component { id: soundPageComponent; SoundPage { settingsRoot: root } }

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

    Component { id: voicePage; VoicePage { settingsRoot: root } }

    Component { id: keyremapPage; KeyboardRemapPage { settingsRoot: root } }

    Component { id: windowsPage; WindowsVmPage { settingsRoot: root } }
}
