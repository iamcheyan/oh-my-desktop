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
    property string searchQuery: ""
    property int wallpaperRefreshNonce: 0
    property bool keyremapApplyConfirmOpen: false
    property bool keyremapDetailOpen: false
    property string keyremapEditingPreset: ""

    readonly property int shellInset: 10
    readonly property int pageInset: 24
    readonly property int minDialogWidth: 860
    readonly property int minDialogHeight: 560
    readonly property int maxDialogWidth: Math.max(minDialogWidth, width - 32)
    readonly property int maxDialogHeight: Math.max(minDialogHeight, height - 48)
    readonly property int defaultDialogWidth: Math.min(1080, Math.max(920, width - 52))
    readonly property int defaultDialogHeight: Math.min(720, Math.max(600, height - 96))
    property bool resizing: false
    property real resizePressX: 0
    property real resizePressY: 0
    property real resizeStartWidth: 0
    property real resizeStartHeight: 0
    property real resizeStartOffsetX: 0
    property real resizeStartOffsetY: 0

    readonly property var primaryPages: [
        { key: "overview", icon: "settings", title: "Overview", keywords: "system summary home" },
        { key: "network", icon: "wifi", title: "Devices & Connection", keywords: "wifi wireless bluetooth internet lan device connection" },
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

    function formatBatteryTime(seconds) {
        if (!Battery.available || seconds <= 0)
            return "--";
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`;
    }

    function clamp(value, min, max) {
        return Math.max(min, Math.min(max, value));
    }

    function parseKeyValue(text) {
        const result = {};
        const lines = String(text || "").split("\n");
        for (const line of lines) {
            const idx = line.indexOf("=");
            if (idx > 0)
                result[line.slice(0, idx)] = line.slice(idx + 1);
        }
        return result;
    }

    function fileUrl(path) {
        if (!path || path.length === 0) return "";
        return path.startsWith("file://") ? path : `file://${path}`;
    }

    function shellQuote(value) {
        return "'" + String(value || "").replace(/'/g, "'\\''") + "'";
    }

    function beginResize(handle, mouse) {
        const pos = root.mapFromItem(handle, mouse.x, mouse.y);
        resizePressX = pos.x;
        resizePressY = pos.y;
        resizeStartWidth = backgroundWidth;
        resizeStartHeight = backgroundHeight;
        resizeStartOffsetX = dragOffsetX;
        resizeStartOffsetY = dragOffsetY;
        resizing = true;
    }

    function updateResize(handle, mouse) {
        if (!resizing)
            return;
        const pos = root.mapFromItem(handle, mouse.x, mouse.y);
        const targetWidth = Math.round(clamp(resizeStartWidth + pos.x - resizePressX, minDialogWidth, maxDialogWidth));
        const targetHeight = Math.round(clamp(resizeStartHeight + pos.y - resizePressY, minDialogHeight, maxDialogHeight));
        Persistent.states.settingsCenter.width = targetWidth;
        Persistent.states.settingsCenter.height = targetHeight;
        dragOffsetX = clamp(resizeStartOffsetX + (targetWidth - resizeStartWidth) / 2, -(width - targetWidth) / 2, (width - targetWidth) / 2);
        dragOffsetY = clamp(resizeStartOffsetY + (targetHeight - resizeStartHeight) / 2, -(height - targetHeight) / 2, (height - targetHeight) / 2);
    }

    function openWallpaperPicker(mode) {
        wallpaperPicker.open(mode);
    }

    readonly property var filteredPrimaryPages: primaryPages.filter(p => pageMatchesSearch(p))

    function pageMatchesSearch(pageEntry) {
        const q = root.searchQuery.trim().toLowerCase();
        if (q.length === 0) return true;
        if (pageEntry.title.toLowerCase().includes(q)) return true;
        if (pageEntry.keywords.toLowerCase().includes(q)) return true;
        if (pageEntry.key.toLowerCase().includes(q)) return true;
        return false;
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

    Rectangle {
        id: settingsShell
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: TuiStyle.bg
        radius: TuiStyle.shellRadius
        border.width: TuiStyle.borderWidth
        border.color: TuiStyle.shellBorder
        clip: true

        RowLayout {
            anchors.fill: parent
            anchors.margins: root.shellInset
            spacing: 0

            Rectangle {
                Layout.preferredWidth: 274
                Layout.fillHeight: true
                radius: TuiStyle.shellRadius - root.shellInset
                color: SettingsTokens.panel

                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: parent.radius
                    color: parent.color
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: 20
                        color: SettingsTokens.panelAlt

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10

                            MaterialSymbol {
                                text: "search"
                                iconSize: 18
                                color: SettingsTokens.accent
                            }

                            TextField {
                                id: searchField
                                Layout.fillWidth: true
                                placeholderText: "Search settings"
                                placeholderTextColor: SettingsTokens.dim
                                color: SettingsTokens.fg
                                font.pixelSize: Appearance.font.pixelSize.small
                                background: Item {}
                                cursorVisible: focus
                                selectByMouse: true
                                onTextChanged: root.searchQuery = text
                                Keys.onPressed: (event) => {
                                    if (event.key === Qt.Key_Escape) {
                                        if (text.length > 0) {
                                            text = "";
                                            event.accepted = true;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.preferredHeight: 4 }

                    StyledFlickable {
                        id: navScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: navColumn.implicitHeight + 8

                        ColumnLayout {
                            id: navColumn
                            width: navScroll.width
                            spacing: 4

                            Repeater {
                                model: root.filteredPrimaryPages
                                delegate: SettingsNavItem {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    iconName: modelData.icon
                                    label: modelData.title
                                    selected: root.currentPage === modelData.key
                                    onClicked: root.currentPage = modelData.key
                                }
                            }

                            Item {
                                Layout.fillHeight: true
                                visible: root.filteredPrimaryPages.length === 0
                                Layout.preferredHeight: 80
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.filteredPrimaryPages.length === 0
                                text: "No matching settings"
                                color: SettingsTokens.dim
                                font.pixelSize: Appearance.font.pixelSize.small
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    SettingsButton {
                        Layout.fillWidth: true
                        label: "Reload Shell"
                        iconName: "refresh"
                        onClicked: Quickshell.reload(true)
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: SettingsTokens.line
                opacity: 0.55
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: TuiStyle.shellRadius - root.shellInset
                color: SettingsTokens.bg
                clip: true

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    width: parent.radius
                    color: parent.color
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Rectangle {
                        id: titleBar
                        Layout.fillWidth: true
                        Layout.preferredHeight: 66
                        color: "transparent"

                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            property real pressX: 0
                            property real pressY: 0
                            property real startOffsetX: 0
                            property real startOffsetY: 0
                            onPressed: (mouse) => {
                                pressX = mouse.x;
                                pressY = mouse.y;
                                startOffsetX = root.dragOffsetX;
                                startOffsetY = root.dragOffsetY;
                                root.dragging = true;
                            }
                            onPositionChanged: (mouse) => {
                                if (pressed) {
                                    root.dragOffsetX += mouse.x - pressX;
                                    root.dragOffsetY += mouse.y - pressY;
                                }
                            }
                            onReleased: root.dragging = false
                            onCanceled: root.dragging = false
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 28
                            anchors.rightMargin: 18
                            spacing: 12

                            StyledText {
                                Layout.fillWidth: true
                                text: root.pageTitle(root.currentPage)
                                color: SettingsTokens.fg
                                font.pixelSize: Appearance.font.pixelSize.huge
                                font.weight: Font.DemiBold
                            }

                            SettingsIconButton {
                                iconName: "close"
                                onClicked: root.dismiss()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: SettingsTokens.line
                        opacity: 0.55
                    }

                    StyledFlickable {
                        id: pageScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: pageLoader.item ? pageLoader.item.implicitHeight + root.pageInset * 2 : 0

                        Loader {
                            id: pageLoader
                            x: root.pageInset
                            y: root.pageInset
                            width: Math.max(0, pageScroll.width - root.pageInset * 2)
                            sourceComponent: {
                                if (root.currentPage === "network") return networkPage;
                                if (root.currentPage === "display") return migratedDisplayPage;
                                if (root.currentPage === "voice") return voicePage;
                                if (root.currentPage === "keyremap") return keyremapPage;
                                if (root.currentPage === "windows") return windowsPage;
                                if (root.currentPage === "overview") return overviewPageComponent;
                                if (root.currentPage === "appearance") return appearancePageComponent;
                                if (root.currentPage === "sound") return soundPageComponent;
                                if (root.currentPage === "power") return powerPageComponent;
                                if (root.currentPage === "system") return systemPageComponent;
                                return overviewPageComponent;
                            }
                            onLoaded: {
                                if (item && item.settingsRoot !== undefined)
                                    item.settingsRoot = root;
                            }
                        }
                    }
                }
            }
        }

        // ── Key editor overlay (floating layer for remap-type presets) ──

        Item {
            id: keyEditorOverlay
            anchors.fill: parent
            visible: root.keyremapEditingPreset !== ""
            z: 55

            Rectangle {
                anchors.fill: parent
                color: "#050505"
                opacity: 0.72

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (keyEditorPopup.visible)
                            keyEditorPopup.close()
                        else
                            root.keyremapEditingPreset = ""
                    }
                }
            }

            Rectangle {
                width: Math.min(420, parent.width - 64)
                height: keyEditorContent.implicitHeight + 48
                anchors.centerIn: parent
                radius: SettingsTokens.roundRadius
                color: SettingsTokens.card
                border.width: 1
                border.color: SettingsTokens.accent

                ColumnLayout {
                    id: keyEditorContent
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        MaterialSymbol {
                            text: "edit"
                            iconSize: 22
                            color: SettingsTokens.accent
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                const preset = KeyboardRemap.presetChoice(root.keyremapEditingPreset)
                                return preset ? `Edit: ${preset.label}` : ""
                            }
                            color: SettingsTokens.fg
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.DemiBold
                        }

                        Rectangle {
                            width: 28
                            height: 28
                            radius: SettingsTokens.radius
                            color: closeBtnMouse.containsMouse ? SettingsTokens.buttonHover : "transparent"

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "close"
                                iconSize: 18
                                color: SettingsTokens.muted
                            }

                            MouseArea {
                                id: closeBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    keyEditorPopup.close()
                                    root.keyremapEditingPreset = ""
                                }
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            const preset = KeyboardRemap.presetChoice(root.keyremapEditingPreset)
                            if (!preset)
                                return ""
                            const current = KeyboardRemap.presetOverride(KeyboardRemap.selectedDeviceId, root.keyremapEditingPreset)
                            const target = current.length > 0 ? current : preset.remaps[0].to
                            return `Source: ${preset.remaps[0].from}    Target: ${target}`
                        }
                        color: SettingsTokens.muted
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.small
                        wrapMode: Text.WordWrap
                    }

                    // Key picker dropdown
                    Rectangle {
                        id: keyEditorTargetBox
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        radius: SettingsTokens.radius
                        color: keyEditorMouse.containsMouse ? SettingsTokens.buttonHover : SettingsTokens.panel
                        border.width: 1
                        border.color: keyEditorPopup.visible ? SettingsTokens.accent : SettingsTokens.line

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 10
                            spacing: 10

                            StyledText {
                                text: "Target:"
                                color: SettingsTokens.dim
                                font.pixelSize: Appearance.font.pixelSize.small
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: {
                                    const current = KeyboardRemap.presetOverride(KeyboardRemap.selectedDeviceId, root.keyremapEditingPreset)
                                    const preset = KeyboardRemap.presetChoice(root.keyremapEditingPreset)
                                    return current.length > 0 ? current : (preset?.remaps?.[0]?.to ?? "")
                                }
                                color: SettingsTokens.fg
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            MaterialSymbol {
                                text: keyEditorPopup.visible ? "expand_less" : "expand_more"
                                iconSize: 20
                                color: SettingsTokens.muted
                            }
                        }

                        MouseArea {
                            id: keyEditorMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (keyEditorPopup.visible)
                                    keyEditorPopup.close()
                                else
                                    keyEditorPopup.open()
                            }
                        }

                        Popup {
                            id: keyEditorPopup
                            y: keyEditorTargetBox.height + 4
                            width: keyEditorTargetBox.width
                            height: Math.min(260, keyEditorList.contentHeight + 8)
                            padding: 4

                            background: Rectangle {
                                radius: SettingsTokens.radius
                                color: SettingsTokens.panel
                                border.width: 1
                                border.color: SettingsTokens.line
                            }

                            contentItem: ListView {
                                id: keyEditorList
                                clip: true
                                model: KeyboardRemap.keyChoices
                                delegate: Rectangle {
                                    required property string modelData
                                    required property int index
                                    width: keyEditorList.width
                                    height: 34
                                    radius: SettingsTokens.radius
                                    readonly property string currentTarget: {
                                        const o = KeyboardRemap.presetOverride(KeyboardRemap.selectedDeviceId, root.keyremapEditingPreset)
                                        if (o.length > 0) return o
                                        return KeyboardRemap.presetChoice(root.keyremapEditingPreset)?.remaps?.[0]?.to ?? ""
                                    }
                                    color: keyChoiceMouse.containsMouse
                                        ? SettingsTokens.cardHover
                                        : (modelData === currentTarget ? SettingsTokens.accentSoft : "transparent")

                                    StyledText {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 10
                                        text: modelData
                                        color: SettingsTokens.fg
                                        font.family: Appearance.font.family.monospace
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }

                                    MouseArea {
                                        id: keyChoiceMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            KeyboardRemap.setPresetOverride(KeyboardRemap.selectedDeviceId, root.keyremapEditingPreset, modelData)
                                            keyEditorPopup.close()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            radius: SettingsTokens.radius
                            color: resetMouse.containsMouse ? SettingsTokens.buttonHover : SettingsTokens.button
                            border.width: 1
                            border.color: SettingsTokens.buttonBorder
                            opacity: KeyboardRemap.presetOverride(KeyboardRemap.selectedDeviceId, root.keyremapEditingPreset).length > 0 ? 1 : 0.45

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                MaterialSymbol { text: "refresh"; iconSize: 16; color: SettingsTokens.fg }
                                StyledText { text: "Reset to default"; color: SettingsTokens.fg; font.pixelSize: Appearance.font.pixelSize.small }
                            }

                            MouseArea {
                                id: resetMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: KeyboardRemap.presetOverride(KeyboardRemap.selectedDeviceId, root.keyremapEditingPreset).length > 0
                                onClicked: KeyboardRemap.setPresetOverride(KeyboardRemap.selectedDeviceId, root.keyremapEditingPreset, "")
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            radius: SettingsTokens.radius
                            color: doneMouse.containsMouse ? SettingsTokens.buttonActive : SettingsTokens.accent
                            border.width: 1
                            border.color: SettingsTokens.accent

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                MaterialSymbol { text: "check"; iconSize: 16; color: "#111111" }
                                StyledText { text: "Done"; color: "#111111"; font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.DemiBold }
                            }

                            MouseArea {
                                id: doneMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    keyEditorPopup.close()
                                    root.keyremapEditingPreset = ""
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: resizeOverlay
            anchors.fill: parent
            visible: root.resizing
            z: 70

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeFDiagCursor
            }
        }

        Item {
            id: resizeHandle
            width: 34
            height: 34
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            z: 65

            Canvas {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 8
                anchors.bottomMargin: 8
                width: 16
                height: 16
                opacity: resizeMouse.containsMouse || root.resizing ? 0.9 : 0.5
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = SettingsTokens.muted;
                    ctx.lineWidth = 1.4;
                    ctx.lineCap = "round";
                    for (let i = 0; i < 3; i++) {
                        const offset = i * 5;
                        ctx.beginPath();
                        ctx.moveTo(width - offset, height);
                        ctx.lineTo(width, height - offset);
                        ctx.stroke();
                    }
                }
            }

            MouseArea {
                id: resizeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeFDiagCursor
                acceptedButtons: Qt.LeftButton
                onPressed: (mouse) => {
                    root.beginResize(resizeMouse, mouse);
                }
                onPositionChanged: (mouse) => {
                    if (pressed)
                        root.updateResize(resizeMouse, mouse);
                }
                onReleased: root.resizing = false
                onCanceled: root.resizing = false
            }
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
        PageBody {
            // ── Bluetooth ──────────────────────────────────────────────
            SettingsCard {
                title: "Bluetooth"
                subtitle: {
                    if (!BluetoothStatus.available) return "Not available"
                    if (!BluetoothStatus.enabled) return "Disabled"
                    if (BluetoothStatus.connected) return `${BluetoothStatus.activeDeviceCount} connected`
                    return "Enabled"
                }

                SettingsToggleRow {
                    label: "Bluetooth radio"
                    description: "Enable or disable Bluetooth"
                    checked: BluetoothStatus.enabled
                    onToggled: {
                        if (Bluetooth.defaultAdapter)
                            Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                    }
                }

                ButtonRow {
                    visible: BluetoothStatus.available
                    SettingsButton { label: "Bluetooth Manager"; iconName: "bluetooth"; onClicked: Quickshell.execDetached(["blueman-manager"]) }
                }
            }

            // ── Wi-Fi Status ─────────────────────────────────────────────
            SettingsCard {
                title: "Wi-Fi"
                subtitle: {
                    if (!Network.wifiEnabled) return "Disabled"
                    if (Network.wifiScanning) return "Scanning..."
                    if (Network.wifiConnecting) return "Connecting..."
                    return Network.wifiStatus
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    SettingsToggleRow {
                        Layout.fillWidth: true
                        label: "Wireless radio"
                        description: "Enable or disable the Wi-Fi adapter"
                        checked: Network.wifiEnabled
                        onToggled: Network.toggleWifi()
                    }

                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: SettingsTokens.radius
                        color: scanMouse.containsMouse ? SettingsTokens.buttonHover : "transparent"
                        visible: Network.wifiEnabled

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "refresh"
                            iconSize: 18
                            color: SettingsTokens.muted
                            RotationAnimator on rotation {
                                running: Network.wifiScanning
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 1200
                            }
                        }

                        MouseArea {
                            id: scanMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Network.rescanWifi()
                        }
                    }
                }

                SettingsRow {
                    label: "Connected network"
                    value: Network.active?.ssid || Network.networkName || "--"
                    visible: Network.wifiEnabled
                }

                SettingsRow {
                    label: "Signal strength"
                    value: Network.active ? `${Network.active.strength}%` : "--"
                    visible: Network.wifiEnabled && Network.active
                }

                ButtonRow {
                    visible: Network.wifiEnabled
                    SettingsButton { label: "Connection Editor"; iconName: "edit"; onClicked: Quickshell.execDetached(["nm-connection-editor"]) }
                    SettingsButton { label: "Network TUI"; iconName: "terminal"; onClicked: Quickshell.execDetached(["foot", "--app-id=nmtui", "--title=nmtui", "--window-size-pixels=880x620", "-e", "nmtui"]) }
                }
            }

            // ── Available Networks ───────────────────────────────────────
            SettingsCard {
                title: "Available Networks"
                subtitle: `${Network.friendlyWifiNetworks.length} found`
                visible: Network.wifiEnabled

                // Scanning placeholder
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    visible: Network.wifiScanning && Network.friendlyWifiNetworks.length === 0
                    color: "transparent"

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 10

                        MaterialSymbol {
                            text: "wifi_find"
                            iconSize: 18
                            color: SettingsTokens.muted
                            SequentialAnimation on opacity {
                                running: Network.wifiScanning
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.4; to: 1.0; duration: 700 }
                                NumberAnimation { from: 1.0; to: 0.4; duration: 700 }
                            }
                        }

                        StyledText {
                            text: "Scanning for networks..."
                            color: SettingsTokens.muted
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }

                Repeater {
                    model: Network.friendlyWifiNetworks.slice(0, 15)
                    delegate: Rectangle {
                        id: netDelegate
                        required property var modelData
                        readonly property var ap: modelData
                        readonly property bool isActive: ap.active ?? false
                        readonly property bool isKnown: Network.isKnownWifi(ap)
                        readonly property bool isConnecting: Network.wifiConnecting && Network.wifiConnectTarget?.ssid === ap.ssid

                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: SettingsTokens.radius
                        color: isActive ? SettingsTokens.accentSoft : (netMouse.containsMouse ? SettingsTokens.cardHover : "transparent")
                        border.width: isActive ? 1 : 0
                        border.color: SettingsTokens.accent

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            // Signal icon
                            MaterialSymbol {
                                text: {
                                    if (netDelegate.isConnecting) return "progress_activity"
                                    const s = netDelegate.ap.strength ?? 0
                                    if (s >= 75) return "wifi"
                                    if (s >= 50) return "network_wifi_3_bar"
                                    if (s >= 25) return "network_wifi_2_bar"
                                    if (s > 0) return "network_wifi_1_bar"
                                    return "wifi_off"
                                }
                                iconSize: 18
                                color: netDelegate.isActive ? SettingsTokens.accent : SettingsTokens.muted
                                Layout.preferredWidth: 22
                                RotationAnimator on rotation {
                                    running: netDelegate.isConnecting
                                    loops: Animation.Infinite
                                    from: 0
                                    to: 360
                                    duration: 1200
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                StyledText {
                                    Layout.fillWidth: true
                                    text: netDelegate.ap.ssid || "Hidden network"
                                    color: SettingsTokens.fg
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: netDelegate.isActive ? Font.Medium : Font.Normal
                                    elide: Text.ElideRight
                                }

                                RowLayout {
                                    spacing: 6

                                    StyledText {
                                        text: netDelegate.isActive ? "Connected" : netDelegate.isConnecting ? "Connecting..." : netDelegate.isKnown ? "Saved" : "New"
                                        color: netDelegate.isActive ? SettingsTokens.accent : SettingsTokens.dim
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                    }

                                    MaterialSymbol {
                                        text: "lock"
                                        iconSize: 14
                                        color: SettingsTokens.dim
                                        visible: netDelegate.ap.security && netDelegate.ap.security.length > 0
                                    }
                                }
                            }

                            StyledText {
                                text: `${netDelegate.ap.strength ?? 0}%`
                                color: SettingsTokens.muted
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                Layout.preferredWidth: 38
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        MouseArea {
                            id: netMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: netDelegate.isActive ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: {
                                if (!netDelegate.isActive && netDelegate.ap.ssid)
                                    Network.connectToWifiNetwork(netDelegate.ap)
                            }
                        }
                    }
                }

                // Empty state
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    visible: Network.friendlyWifiNetworks.length === 0 && !Network.wifiScanning
                    color: "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: "No networks found. Click scan to search."
                        color: SettingsTokens.dim
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }

            // ── Ethernet ─────────────────────────────────────────────────
            SettingsCard {
                title: "Ethernet"
                subtitle: Network.ethernet ? "Connected" : "Not connected"
                visible: !Network.wifi || Network.ethernet

                SettingsRow {
                    label: "Status"
                    value: Network.ethernet ? "Connected" : "Disconnected"
                }

                SettingsRow {
                    label: "Interface"
                    value: Network.networkName || "--"
                    visible: Network.ethernet
                }
            }
        }
    }

    Component {
        id: voicePage
        PageBody {
            readonly property string omdRoot: `${FileUtils.trimFileProtocol(Directories.config)}/omd`
            property var voicePageBindings: []

            SettingsCard {
                title: "Voice Engine"
                subtitle: VoiceInput.state === "setup" ? "Needs setup" : VoiceInput.daemonRunning ? "Daemon running" : "Daemon idle"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    SettingsStatusPill { label: VoiceInput.state === "idle" ? "ready" : VoiceInput.state; active: VoiceInput.state === "idle" }
                    SettingsStatusPill { label: VoiceInput.modelSizeMB > 0 ? `${VoiceInput.modelSizeMB} MB model` : "no model"; active: VoiceInput.modelSizeMB > 0; warning: VoiceInput.modelSizeMB === 0 }
                    SettingsStatusPill { label: VoiceInput.daemonRunning ? "daemon up" : "daemon down"; active: VoiceInput.daemonRunning }
                }

                SettingsRow {
                    label: "Engine state"
                    value: VoiceInput.state
                }
                SettingsRow {
                    label: "Last result"
                    description: VoiceInput.lastTranscription.length > 0 ? VoiceInput.lastTranscription.slice(0, 100) : "--"
                }
                SettingsRow {
                    visible: VoiceInput.lastError.length > 0
                    label: "Last error"
                    description: VoiceInput.lastError
                }

                ButtonRow {
                    SettingsButton {
                        label: VoiceInput.state === "recording" ? "Stop" : VoiceInput.state === "transcribing" ? "Transcribing…" : "Record"
                        iconName: "keyboard_voice"
                        enabledState: VoiceInput.state === "idle" || VoiceInput.state === "recording"
                        active: VoiceInput.state === "recording"
                        onClicked: VoiceInput.toggle()
                    }
                    SettingsButton {
                        label: VoiceInput.state === "setup" ? "Setup" : "Recheck"
                        iconName: "download"
                        onClicked: {
                            if (VoiceInput.state === "setup")
                                VoiceInput.setup()
                            else
                                VoiceInput.checkState()
                        }
                    }
                }
            }

            SettingsCard {
                title: "Keybindings"
                subtitle: voicePageBindings.length > 0 ? `${voicePageBindings.length} active` : "No bindings"

                Repeater {
                    model: voicePageBindings
                    delegate: SettingsRow {
                        required property var modelData
                        iconName: "keyboard"
                        label: modelData
                    }
                }

                ButtonRow {
                    SettingsButton {
                        label: "Configure"
                        iconName: "settings"
                        onClicked: Quickshell.execDetached(["omd-launch-tui", `${omdRoot}/scripts/voice-bind-tui`])
                    }
                    SettingsButton {
                        label: "Capture Key"
                        iconName: "keyboard"
                        onClicked: Quickshell.execDetached([`${omdRoot}/scripts/key-test-launcher`, "--hotkey"])
                    }
                }

            }

            Process {
                id: voiceBindingsProc
                command: ["bash", "-c", "cat ~/.config/omd/config/voice_bindings.txt 2>/dev/null || echo ''"]
                running: true
                stdout: StdioCollector {
                    id: voiceBindingsCollector
                    onStreamFinished: {
                        const text = voiceBindingsCollector.text.trim()
                        voicePageBindings = text.length > 0
                            ? text.split("\n").filter(l => l.length > 0 && !l.startsWith("#"))
                            : []
                    }
                }
            }

            SettingsCard {
                title: "Test & Diagnostics"
                subtitle: "Verify recording and troubleshoot"

                ButtonRow {
                    SettingsButton {
                        label: "Quick Test"
                        iconName: "mic"
                        enabledState: VoiceInput.state === "idle"
                        onClicked: VoiceInput.testRecording()
                    }
                    SettingsButton {
                        label: "TUI Test"
                        iconName: "terminal"
                        onClicked: Quickshell.execDetached(["omd-launch-tui", `${omdRoot}/scripts/voice-test-tui`])
                    }
                }
                ButtonRow {
                    SettingsButton {
                        label: "Diagnose"
                        iconName: "health_and_safety"
                        onClicked: Quickshell.execDetached(["omd-launch-tui", `${omdRoot}/scripts/voice-diagnose`])
                    }
                    SettingsButton {
                        label: "Clear History"
                        iconName: "clear_all"
                        onClicked: VoiceInput.clearHistory()
                    }
                }
            }

            SettingsCard {
                title: "History"
                subtitle: `${VoiceInput.history.length} entries`
                visible: VoiceInput.history.length > 0

                Repeater {
                    model: VoiceInput.history.slice(0, 8)
                    delegate: SettingsRow {
                        required property var modelData
                        iconName: "history"
                        label: modelData.text ? modelData.text.slice(0, 80) : "--"
                        value: modelData.time || ""
                    }
                }
            }

            SettingsCard {
                title: "Paths & Cache"
                subtitle: "Runtime directories"
                SettingsRow { label: "Cache dir"; value: VoiceInput.cacheDir }
                SettingsRow { label: "Model dir"; value: VoiceInput.modelDir }
                SettingsRow { label: "Venv dir"; value: VoiceInput.venvDir }
                SettingsRow { label: "Socket"; value: "/tmp/omd-voice.sock" }
            }
        }
    }

    Component {
        id: keyremapPage
        PageBody {
            id: keyremapRoot

            // ── Status card (always visible) ──

            SettingsCard {
                title: "Keyboard Remap"
                subtitle: KeyboardRemap.hasPendingChanges ? "Draft changes are waiting to be applied" : "Current keyd config matches this page"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    SettingsStatusPill { label: KeyboardRemap.keydReady ? "keyd running" : "keyd not ready"; active: KeyboardRemap.keydReady; warning: !KeyboardRemap.keydReady }
                    SettingsStatusPill { label: `${KeyboardRemap.devices.length} connected`; active: KeyboardRemap.devices.length > 0 }
                    SettingsStatusPill {
                        label: KeyboardRemap.hasPendingChanges ? "pending" : "applied"
                        active: !KeyboardRemap.hasPendingChanges
                        warning: KeyboardRemap.hasPendingChanges
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: "Select a keyboard to enable presets for it."
                    color: SettingsTokens.muted
                    font.pixelSize: Appearance.font.pixelSize.small
                    wrapMode: Text.WordWrap
                }

                SettingsRow {
                    visible: KeyboardRemap.lastError.length > 0
                    iconName: "warning"
                    label: "Apply error"
                    description: KeyboardRemap.lastError
                    valueColor: "#f07070"
                }

                ButtonRow {
                    SettingsButton {
                        label: KeyboardRemap.state === "setup" ? "Setup keyd" : "Recheck"
                        iconName: KeyboardRemap.state === "setup" ? "download" : "refresh"
                        onClicked: {
                            if (KeyboardRemap.state === "setup")
                                KeyboardRemap.setup();
                            else
                                KeyboardRemap.checkKeyd();
                        }
                    }
                    SettingsButton {
                        label: KeyboardRemap.applyInProgress ? "Applying..." : "Apply changes"
                        iconName: "check"
                        active: KeyboardRemap.hasPendingChanges
                        enabledState: KeyboardRemap.hasPendingChanges && !KeyboardRemap.applyInProgress
                        onClicked: root.keyremapApplyConfirmOpen = true
                    }
                    SettingsButton {
                        label: "Refresh"
                        iconName: "refresh"
                        onClicked: {
                            KeyboardRemap.refreshDevices();
                            KeyboardRemap.loadProfiles();
                            KeyboardRemap.checkKeyd();
                        }
                    }
                }
            }

            // ── Apply confirmation ──

            SettingsCard {
                visible: root.keyremapApplyConfirmOpen && KeyboardRemap.hasPendingChanges
                title: "Apply keyboard remaps?"
                subtitle: "This writes /etc/keyd/omd.conf and restarts keyd"

                SettingsRow {
                    iconName: "security"
                    label: "Authorization required"
                    description: `${KeyboardRemap.devices.length} keyboard${KeyboardRemap.devices.length === 1 ? "" : "s"}`
                    value: "keyd"
                    valueColor: SettingsTokens.accent
                }

                ButtonRow {
                    SettingsButton {
                        label: "Apply"
                        iconName: "check"
                        active: true
                        enabledState: !KeyboardRemap.applyInProgress
                        onClicked: {
                            root.keyremapApplyConfirmOpen = false;
                            KeyboardRemap.apply();
                        }
                    }
                    SettingsButton {
                        label: "Cancel"
                        iconName: "close"
                        enabledState: !KeyboardRemap.applyInProgress
                        onClicked: root.keyremapApplyConfirmOpen = false
                    }
                }
            }

            // ══ TOP-LEVEL: Keyboard list ══

            SettingsCard {
                visible: !root.keyremapDetailOpen
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                title: "Keyboards"
                subtitle: KeyboardRemap.availableDevices.length > 0 ? "Connected and saved keyboard profiles" : "No keyboards detected"

                Repeater {
                    model: KeyboardRemap.availableDevices
                    delegate: SettingsRow {
                        required property var modelData
                        readonly property int presetCount: KeyboardRemap.devicePresetCount(modelData.hyprName)
                        iconName: "keyboard"
                        label: modelData.displayName
                        description: modelData.connected
                            ? (modelData.keydId || "missing keyd id")
                            : `${modelData.keydId || "missing keyd id"} · saved, disconnected`
                        value: presetCount > 0 ? `${presetCount} preset${presetCount === 1 ? "" : "s"}` : "no presets"
                        valueColor: presetCount > 0 ? SettingsTokens.accent : SettingsTokens.muted
                        rightInset: 30
                        showChevron: true
                        onClicked: {
                            KeyboardRemap.selectDevice(modelData.hyprName);
                            root.keyremapDetailOpen = true;
                        }

                        // Green dot — connected indicator
                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8
                            height: 8
                            radius: 4
                            color: modelData.connected ? "#4ade80" : SettingsTokens.muted
                            border.width: 1
                            border.color: modelData.connected ? "#22c55e" : SettingsTokens.line
                        }
                    }
                }

                SettingsRow {
                    visible: KeyboardRemap.availableDevices.length === 0
                    iconName: "info"
                    label: "No keyboards found"
                    description: "Refresh after connecting a keyboard."
                }
            }

            // ══ DETAIL VIEW: Per-keyboard preset configuration ══

            // ── Device header + enable toggle ──

            SettingsCard {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                title: KeyboardRemap.selectedDeviceId !== "" ? (KeyboardRemap.selectedProfile?.displayName ?? KeyboardRemap.selectedDeviceId) : "Keyboard"
                subtitle: {
                    if (KeyboardRemap.selectedDeviceId === "")
                        return ""
                    const n = KeyboardRemap.devicePresetCount(KeyboardRemap.selectedDeviceId)
                    return n > 0 ? `${n} preset${n === 1 ? "" : "s"} active` : "No presets active"
                }
                visible: root.keyremapDetailOpen && KeyboardRemap.selectedDeviceId !== ""

                ButtonRow {
                    SettingsButton {
                        label: "Back to keyboards"
                        iconName: "chevron_left"
                        onClicked: root.keyremapDetailOpen = false
                    }
                    SettingsButton {
                        visible: KeyboardRemap.selectedDevice?.connected === false
                        label: "Remove saved profile"
                        iconName: "delete"
                        onClicked: {
                            KeyboardRemap.deleteProfile(KeyboardRemap.selectedDeviceId)
                            root.keyremapDetailOpen = false
                        }
                    }
                }

                SettingsRow {
                    iconName: "badge"
                    label: KeyboardRemap.selectedDevice?.keydId || "Missing keyd id"
                    description: KeyboardRemap.selectedKeydIdMissing ? "Remaps cannot apply until this ID is resolved." : "keyd vendor:product id"
                    value: KeyboardRemap.selectedEnabled ? "Enabled" : "Disabled"
                    valueColor: KeyboardRemap.selectedEnabled ? SettingsTokens.accent : SettingsTokens.muted
                }

                SettingsToggleRow {
                    iconName: "power_settings_new"
                    label: "Enable this keyboard"
                    description: "When off, no presets are emitted for this keyboard."
                    checked: KeyboardRemap.selectedEnabled
                    onToggled: KeyboardRemap.setProfileEnabled(!KeyboardRemap.selectedEnabled)
                }
            }

            // ── Preset toggles for this keyboard ──

            SettingsCard {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                title: "Presets"
                subtitle: {
                    const n = KeyboardRemap.devicePresetCount(KeyboardRemap.selectedDeviceId)
                    return n > 0 ? `${n} enabled` : "Toggle presets for this keyboard"
                }
                visible: root.keyremapDetailOpen && KeyboardRemap.selectedDeviceId !== ""

                Repeater {
                    model: KeyboardRemap.globalPresetChoices
                    delegate: SettingsRow {
                        required property var modelData
                        readonly property bool isRemap: modelData.type === "remap"
                        readonly property string overrideKey: KeyboardRemap.presetOverride(KeyboardRemap.selectedDeviceId, modelData.id)
                        readonly property string effectiveTarget: overrideKey.length > 0 ? overrideKey : (modelData.remaps?.[0]?.to ?? "")
                        iconName: "tune"
                        label: modelData.label
                        description: overrideKey.length > 0
                            ? `${modelData.remaps[0].from} → ${overrideKey} (custom)`
                            : modelData.description
                        value: ""
                        rightInset: isRemap ? 110 : 70
                        showChevron: false
                        onClicked: KeyboardRemap.setDevicePresetEnabled(KeyboardRemap.selectedDeviceId, modelData.id, !KeyboardRemap.devicePresetEnabled(KeyboardRemap.selectedDeviceId, modelData.id))

                        // Edit button — only for remap-type presets
                        Rectangle {
                            visible: isRemap
                            anchors.right: toggleSwitch.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32
                            height: 32
                            radius: SettingsTokens.radius
                            color: editMouse.containsMouse ? SettingsTokens.buttonHover : "transparent"

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "edit"
                                iconSize: 16
                                color: overrideKey.length > 0 ? SettingsTokens.accent : SettingsTokens.muted
                            }

                            MouseArea {
                                id: editMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.keyremapEditingPreset = modelData.id
                            }
                        }

                        // Toggle switch
                        Rectangle {
                            id: toggleSwitch
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 46
                            height: 26
                            radius: height / 2
                            color: KeyboardRemap.devicePresetEnabled(KeyboardRemap.selectedDeviceId, modelData.id) ? SettingsTokens.accent : SettingsTokens.line

                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                x: KeyboardRemap.devicePresetEnabled(KeyboardRemap.selectedDeviceId, modelData.id) ? parent.width - width - 3 : 3
                                color: KeyboardRemap.devicePresetEnabled(KeyboardRemap.selectedDeviceId, modelData.id) ? "#111111" : "#dedede"
                                Behavior on x { NumberAnimation { duration: 110 } }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: windowsPage
        PageBody {
            QtObject {
                id: s

                property string pageState: "idle"

                property bool configured: false
                property bool kvm: false
                property bool dockerCli: false
                property bool dockerRunning: false
                property bool compose: false
                property bool freerdp: false
                property string container: "missing"
                property string web: "http://127.0.0.1:8006"
                property string ram: ""
                property string cpu: ""
                property string disk: ""
                property string user: ""

                property int diskAvailable: 0
                property int ramTotal: 0
                property int cpuTotal: 0

                property string installPhase: ""
                property bool installReady: false
                property bool webReachable: false
                property bool installRunning: false
                property string autoStep: ""
                property string autoError: ""
                property string autoWarning: ""

                readonly property bool running: container === "running"
                readonly property bool allReady: s.kvm && s.dockerRunning && s.freerdp && s.diskAvailable >= 42
                readonly property bool hasIssues: !s.kvm || !s.dockerRunning || !s.freerdp || s.diskAvailable < 42
                    || (s.configured && s.container === "exited")

                function refresh() { windowsStatusProc.running = true; }
                function run(action) {
                    windowsActionProc.command = ["bash", "-c", `$HOME/.config/omd/bin/omd-settings-windows-vm ${action}`];
                    windowsActionProc.running = true;
                }
                function fmtr(val) { return val > 0 ? `${val} GB` : `--`; }

                function startAutoInstall() {
                    s.pageState = "auto";
                    s.autoStep = "Checking KVM...";
                    s.autoError = "";
                    s.autoWarning = "";
                    windowsAutoTimer.step = 0;
                    autoDoStep();
                }

            }

            // === STATUS HEADER ===
            SettingsCard {
                title: "Windows VM"
                subtitle: s.running ? "Running" : s.configured ? "Installed" : "Not installed"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    SettingsStatusPill { label: "Status"; active: s.running; warning: s.configured && !s.running }
                    SettingsStatusPill { label: s.kvm ? "KVM" : "No KVM"; active: s.kvm; warning: !s.kvm }
                    SettingsStatusPill { label: s.dockerRunning ? "Docker" : "No Docker"; active: s.dockerRunning; warning: !s.dockerRunning }
                }

                SettingsRow {
                    label: "Container"
                    value: s.container
                    valueColor: s.running ? SettingsTokens.accent : SettingsTokens.muted
                }
                SettingsRow {
                    label: "Web console"
                    value: s.web
                    showChevron: true
                    onClicked: s.run("web")
                }
            }

            // === ONE-CLICK BUTTON ===
            SettingsCard {
                title: s.pageState === "auto" ? "Auto Installing..." : "Quick Actions"

                ButtonRow {
                    SettingsButton {
                        label: {
                            if (s.pageState === "auto") return `${s.autoStep}...`;
                            if (!s.configured) return "一键安装";
                            if (s.hasIssues) return "一键修复";
                            return "Reinstall";
                        }
                        iconName: {
                            if (s.pageState === "auto") return "hourglass";
                            if (s.hasIssues) return "build";
                            return "download";
                        }
                        active: s.pageState === "auto"
                        onClicked: {
                            if (s.pageState === "auto") return;
                            if (s.configured) {
                                // Reinstall — quick with defaults
                                s.pageState = "auto";
                                s.autoStep = "Reinstalling...";
                                s.autoError = "";
                                s.autoWarning = "";
                                // Use existing config values if available
                                const r = s.ram.replace(/[^0-9]/g, "") || Math.min(Math.floor(s.ramTotal / 2), 64);
                                const c = s.cpu.replace(/[^0-9]/g, "") || Math.min(Math.floor(s.cpuTotal / 2), s.cpuTotal);
                                const d = s.disk.replace(/[^0-9]/g, "") || "64";
                                const u = s.user || "docker";
                                s.run(`install ${r}G ${c} ${d}G "${u}" "admin"`);
                                s.installRunning = true;
                                windowsInstallTimer.running = true;
                            } else {
                                s.startAutoInstall();
                            }
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: s.autoWarning.length > 0
                    text: s.autoWarning
                    color: "#f9a825"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: s.autoError.length > 0
                    text: s.autoError
                    color: "#e53935"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }
            }

            // === AUTO-INSTALL PROGRESS ===
            SettingsCard {
                visible: s.pageState === "auto"
                title: "Installation Progress"

                StyledProgressBar {
                    Layout.fillWidth: true
                    valueBarHeight: 8
                    indeterminate: true
                    wavy: true
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    text: {
                        if (s.installReady) return "Windows is ready! Connecting...";
                        if (s.webReachable) return "Web console reachable. Windows setup in progress...";
                        if (s.autoStep.length > 0) return s.autoStep;
                        if (s.installPhase.length > 0) return `Phase: ${s.installPhase}`;
                        return "Preparing...";
                    }
                    color: SettingsTokens.muted
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    Layout.topMargin: 8
                    visible: windowsLogsOutput.text.length > 0
                    color: SettingsTokens.surface
                    radius: 4
                    clip: true
                    StyledFlickable {
                        anchors.fill: parent
                        anchors.margins: 4
                        contentHeight: autoLogsText.height
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: StyledScrollBar {}
                        TextEdit {
                            id: autoLogsText
                            text: windowsLogsOutput.text
                            color: SettingsTokens.onSurface
                            font.family: Appearance.font.monoFamily
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            selectByMouse: true
                            readOnly: true
                            wrapMode: TextEdit.Wrap
                            width: parent.width
                        }
                    }
                }

                RowLayout {
                    spacing: 8
                    SettingsButton {
                        label: "Open Web Console"
                        iconName: "open_in_browser"
                        enabledState: s.webReachable
                        onClicked: s.run("web")
                    }
                    SettingsButton {
                        label: "Details"
                        iconName: "refresh"
                        onClicked: { windowsInstallStatusProc.running = true; windowsLogsProc.running = true; }
                    }
                }
            }

            // === MANAGE ===
            SettingsCard {
                visible: s.pageState === "manage"
                title: "Manage VM"

                ButtonRow {
                    SettingsButton {
                        label: "Connect"
                        iconName: "login"
                        enabledState: s.configured
                        onClicked: Quickshell.execDetached(["bash", "-c", "$HOME/.config/omd/bin/omd-settings-windows-vm launch"])
                    }
                    SettingsButton {
                        label: "Keep Alive"
                        iconName: "keep"
                        enabledState: s.configured
                        onClicked: Quickshell.execDetached(["bash", "-c", "$HOME/.config/omd/bin/omd-settings-windows-vm launch-keepalive"])
                    }
                }
                ButtonRow {
                    SettingsButton {
                        label: "Stop"
                        iconName: "stop"
                        enabledState: s.configured && s.container !== "missing"
                        onClicked: s.run("stop")
                    }
                    SettingsButton {
                        label: "Open Console"
                        iconName: "open_in_browser"
                        enabledState: s.configured
                        onClicked: s.run("web")
                    }
                    SettingsButton {
                        label: "Remove"
                        iconName: "delete"
                        enabledState: s.configured
                        onClicked: { s.run("remove"); s.pageState = "idle"; }
                    }
                }

                SettingsRow {
                    label: "RAM"
                    value: s.ram.length > 0 ? s.ram : "--"
                }
                SettingsRow {
                    label: "CPU"
                    value: s.cpu.length > 0 ? s.cpu : "--"
                }
                SettingsRow {
                    label: "Disk"
                    value: s.disk.length > 0 ? s.disk : "--"
                }
                SettingsRow {
                    label: "User"
                    value: s.user.length > 0 ? s.user : "--"
                }
            }

            // === LOGS (manage state) ===
            SettingsCard {
                visible: s.pageState === "manage" && s.container !== "missing"
                title: "Container Logs"
                SettingsRow {
                    label: "Refresh"
                    showChevron: true
                    onClicked: windowsLogsProc.running = true
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 180
                    Layout.topMargin: 8
                    visible: windowsLogsOutput.text.length > 0
                    color: SettingsTokens.surface
                    radius: 4
                    clip: true
                    StyledFlickable {
                        anchors.fill: parent; anchors.margins: 4
                        contentHeight: mgtLogsText.height
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: StyledScrollBar {}
                        TextEdit {
                            id: mgtLogsText
                            text: windowsLogsOutput.text
                            color: SettingsTokens.onSurface
                            font.family: Appearance.font.monoFamily
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            selectByMouse: true; readOnly: true
                            wrapMode: TextEdit.Wrap; width: parent.width
                        }
                    }
                }
            }

            // === TIMERS ===

            Timer {
                id: windowsAutoTimer
                interval: 500
                repeat: false
                running: false
                property int step: 0
                onTriggered: autoDoStep()
            }

            function autoDoStep() {
                windowsAutoTimer.step++;
                const step = windowsAutoTimer.step;

                if (step === 1) {
                    s.autoStep = "Checking KVM virtualization..."; s.run("check-resources"); return;
                }
                if (step === 2) {
                    if (!s.kvm) { s.autoStep = "KVM missing. Attempting to load module..."; s.run("auto-fix"); return; }
                    windowsAutoTimer.step = 3; autoDoStep(); return;
                }
                if (step === 3) {
                    if (!s.kvm) { s.autoError = "KVM not available. Enable virtualization in BIOS."; s.pageState = "idle"; return; }
                    windowsAutoTimer.step = 4; autoDoStep(); return;
                }
                if (step === 4) {
                    s.autoStep = "Checking Docker..."; s.run("check-resources"); return;
                }
                if (step === 5) {
                    if (!s.dockerRunning) { s.autoStep = "Starting Docker..."; s.run("install-docker"); return; }
                    windowsAutoTimer.step = 7; autoDoStep(); return;
                }
                if (step === 6) {
                    s.autoStep = "Verifying Docker..."; s.run("check-resources"); return;
                }
                if (step === 7) {
                    if (!s.dockerRunning) { s.autoError = "Failed to start Docker."; s.pageState = "idle"; return; }
                    windowsAutoTimer.step = 8; autoDoStep(); return;
                }
                if (step === 8) {
                    s.autoStep = "Checking FreeRDP..."; s.run("check-resources"); return;
                }
                if (step === 9) {
                    if (!s.freerdp) { s.autoStep = "Installing FreeRDP..."; s.run("install-packages"); return; }
                    windowsAutoTimer.step = 11; autoDoStep(); return;
                }
                if (step === 10) {
                    s.autoStep = "Verifying FreeRDP..."; s.run("check-resources"); return;
                }
                if (step === 11) {
                    if (!s.freerdp) s.autoWarning = "FreeRDP not installed. RDP may fail.";
                    windowsAutoTimer.step = 12; autoDoStep(); return;
                }
                if (step === 12) {
                    s.autoStep = "Checking disk space..."; s.run("check-resources"); return;
                }
                if (step === 13) {
                    if (s.diskAvailable < 42) { s.autoError = `Low disk: ${s.diskAvailable}GB. Need 42GB+.`; s.pageState = "idle"; return; }
                    const r = Math.min(Math.max(2, Math.floor(s.ramTotal / 2)), 64);
                    const c = Math.min(Math.max(1, Math.floor(s.cpuTotal / 2)), s.cpuTotal);
                    const d = Math.min(Math.max(32, s.diskAvailable - 10), 256);
                    s.autoStep = `Installing (${r}G RAM, ${c} CPU, ${d}G disk)...`;
                    s.run(`install ${r}G ${c} ${d}G "docker" "admin"`);
                    return;
                }
                if (step === 14) {
                    s.autoStep = "Starting container...";
                    s.installRunning = true;
                    windowsInstallTimer.running = true;
                    windowsLogsTimer.running = true;
                }
            }

            Timer {
                id: windowsInstallTimer
                interval: 5000
                repeat: true
                running: false
                onTriggered: {
                    windowsInstallStatusProc.running = true;
                }
            }

            Timer {
                id: windowsLogsTimer
                interval: 8000
                repeat: true
                running: false
                onTriggered: windowsLogsProc.running = true
            }

            Timer {
                interval: 8000
                repeat: true
                running: s.pageState !== "auto"
                onTriggered: { s.refresh(); }
            }

            // === PROCESSES ===

            Process {
                id: windowsStatusProc
                command: ["bash", "-c", "$HOME/.config/omd/bin/omd-settings-windows-vm status"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        const d = root.parseKeyValue(text);
                        s.configured = d.configured === "true";
                        s.kvm = d.kvm === "true";
                        s.dockerCli = d.dockerCli === "true";
                        s.dockerRunning = d.dockerRunning === "true";
                        s.compose = d.compose === "true";
                        s.container = d.container || "missing";
                        s.web = d.web || "http://127.0.0.1:8006";
                        s.ram = d.ram || "";
                        s.cpu = d.cpu || "";
                        s.disk = d.disk || "";
                        s.user = d.user || "";
                    }
                }
            }

            Process {
                id: windowsResourcesProc
                command: ["bash", "-c", "$HOME/.config/omd/bin/omd-settings-windows-vm check-resources"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        const d = root.parseKeyValue(text);
                        s.kvm = d.kvm === "true";
                        s.dockerCli = d.dockerCli === "true";
                        s.dockerRunning = d.dockerRunning === "true";
                        s.freerdp = d.freerdp === "true";
                        s.diskAvailable = parseInt(d.diskAvailable || "0");
                        s.ramTotal = parseInt(d.ramTotal || "0");
                        s.cpuTotal = parseInt(d.cpuTotal || "0");
                    }
                }
            }

            Process {
                id: windowsInstallStatusProc
                running: false
                command: ["bash", "-c", "$HOME/.config/omd/bin/omd-settings-windows-vm install-status"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        const d = root.parseKeyValue(text);
                        if (d.state === "running") {
                            s.installPhase = d.phase || "booting";
                            s.webReachable = d.webReachable === "true";
                            if (d.ready === "true") {
                                s.installReady = true;
                                s.installRunning = false;
                                s.autoStep = "Windows is ready!";
                                windowsInstallTimer.running = false;
                                windowsLogsTimer.running = false;
                                s.pageState = "manage";
                                s.refresh();
                            }
                        } else if (d.state === "exited") {
                            s.autoStep = "Container stopped unexpectedly.";
                            s.installRunning = false;
                            windowsInstallTimer.running = false;
                            s.autoWarning = "The container exited. Click 一键修复 or check logs.";
                            s.pageState = "idle";
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
                onExited: (code, status) => {
                    s.refresh();
                    windowsResourcesProc.running = true;
                    if (s.pageState === "auto" && !windowsInstallTimer.running) {
                        windowsAutoTimer.running = true;
                    }
                }
            }
        }
    }
}
