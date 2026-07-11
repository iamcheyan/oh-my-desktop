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
    property var bluetoothConfirmDevice: null
    property bool bluetoothConfirmOpen: false
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
        { key: "network", icon: "wifi", title: "Network & Wireless", keywords: "wifi wireless lan internet ssid" },
        { key: "bluetooth", icon: "bluetooth", title: "Bluetooth", keywords: "bt adapter devices pair" },
        { key: "sound", icon: "volume_up", title: "Sound & Feedback", keywords: "audio volume mute speaker microphone input output sounds feedback osd" },
        { key: "display", icon: "desktop_windows", title: "Displays", keywords: "screen brightness night light monitor resolution refresh scale osd" },
        { key: "appearance", icon: "palette", title: "Appearance", keywords: "theme wallpaper font color look style themes" },
        { key: "power", icon: "battery_charging_full", title: "Power & Battery", keywords: "energy charging profile battery idle sleep" },
        { key: "notifications", icon: "notifications", title: "Notifications", keywords: "notifications clipboard session osd dnd popup" },
        { key: "system", icon: "settings_applications", title: "System", keywords: "autostart startup window rules default apps applications" }
    ]

    readonly property var advancedPages: [
        { key: "voice", icon: "keyboard_voice", title: "Voice Input", keywords: "speech transcribe sherpa microphone dictation record model keybinding diagnostic" },
        { key: "keyremap", icon: "keyboard", title: "Keyboard Remap", keywords: "keyboard remap keyd map caps ctrl modifier bluetooth wired device profile" },
        { key: "windows", icon: "desktop_windows", title: "Windows VM", keywords: "virtualization virtual machine vm docker kvm rdp windows" }
    ]

    readonly property var pages: primaryPages.concat(advancedPages)

    property bool advancedNavExpanded: false


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
        if (page === "osd") return "notifications";
        if (page === "session") return "notifications";
        if (page === "notifications") return "notifications";
        if (page === "clipboard") return "notifications";
        if (page === "idle") return "notifications";
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

    function bluetoothDeviceName(device) {
        return device?.name || device?.deviceName || device?.address || "Unknown device";
    }

    function openBluetoothConfirm(device) {
        if (!device)
            return;
        bluetoothConfirmDevice = device;
        bluetoothConfirmOpen = true;
    }

    function closeBluetoothConfirm() {
        bluetoothConfirmOpen = false;
        bluetoothConfirmDevice = null;
    }

    function confirmBluetoothAction() {
        if (!bluetoothConfirmDevice)
            return;
        BluetoothStatus.connectDevice(bluetoothConfirmDevice);
        closeBluetoothConfirm();
    }

    function openWallpaperPicker(mode) {
        wallpaperPicker.open(mode);
    }

    readonly property var filteredPrimaryPages: primaryPages.filter(p => pageMatchesSearch(p))
    readonly property var filteredAdvancedPages: advancedPages.filter(p => pageMatchesSearch(p))

    function pageMatchesSearch(pageEntry) {
        const q = root.searchQuery.trim().toLowerCase();
        if (q.length === 0) return true;
        if (pageEntry.title.toLowerCase().includes(q)) return true;
        if (pageEntry.keywords.toLowerCase().includes(q)) return true;
        if (pageEntry.key.toLowerCase().includes(q)) return true;
        return false;
    }

    onRequestedPageChanged: currentPage = normalizePage(requestedPage)
    onCurrentPageChanged: {
        if (advancedPages.some(p => p.key === currentPage))
            advancedNavExpanded = true;
    }
    onVisibleChanged: {
        if (visible) {
            currentPage = normalizePage(requestedPage);
            if (advancedPages.some(p => p.key === currentPage))
                advancedNavExpanded = true;
            root.forceActiveFocus();
        }
    }

    Keys.onPressed: (event) => {
        if (root.bluetoothConfirmOpen && (event.key === Qt.Key_Escape || event.key === Qt.Key_Q)) {
            root.closeBluetoothConfirm();
            event.accepted = true;
            return;
        }
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

                            SettingsNavItem {
                                Layout.fillWidth: true
                                iconName: root.advancedNavExpanded ? "expand_less" : "expand_more"
                                label: "Advanced"
                                selected: root.advancedPages.some(p => p.key === root.currentPage)
                                onClicked: root.advancedNavExpanded = !root.advancedNavExpanded
                            }

                            Repeater {
                                model: root.advancedNavExpanded ? root.filteredAdvancedPages : []
                                delegate: SettingsNavItem {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 12
                                    iconName: modelData.icon
                                    label: modelData.title
                                    selected: root.currentPage === modelData.key
                                    onClicked: root.currentPage = modelData.key
                                }
                            }

                            Item {
                                Layout.fillHeight: true
                                visible: root.filteredPrimaryPages.length === 0 && root.filteredAdvancedPages.length === 0
                                Layout.preferredHeight: 80
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.filteredPrimaryPages.length === 0 && root.filteredAdvancedPages.length === 0
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
                                if (root.currentPage === "bluetooth") return bluetoothPage;
                                if (root.currentPage === "display") return migratedDisplayPage;
                                if (root.currentPage === "voice") return voicePage;
                                if (root.currentPage === "keyremap") return keyremapPage;
                                if (root.currentPage === "windows") return windowsPage;
                                if (root.currentPage === "overview") return overviewPageComponent;
                                if (root.currentPage === "appearance") return appearancePageComponent;
                                if (root.currentPage === "sound") return soundPageComponent;
                                if (root.currentPage === "notifications") return notificationsPageComponent;
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

        Item {
            anchors.fill: parent
            visible: root.bluetoothConfirmOpen
            z: 50

            Rectangle {
                anchors.fill: parent
                color: "#050505"
                opacity: 0.72

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.closeBluetoothConfirm()
                }
            }

            Rectangle {
                width: Math.min(460, parent.width - 64)
                height: 230
                anchors.centerIn: parent
                radius: SettingsTokens.roundRadius
                color: SettingsTokens.card
                border.width: 1
                border.color: SettingsTokens.accent

                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        MaterialSymbol {
                            text: root.bluetoothConfirmDevice?.connected ? "bluetooth_disabled" : "bluetooth_connected"
                            iconSize: 22
                            color: root.bluetoothConfirmDevice?.connected ? "#f07070" : SettingsTokens.accent
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.bluetoothConfirmDevice?.connected ? "Disconnect Bluetooth device?" : "Connect Bluetooth device?"
                            color: SettingsTokens.fg
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.bluetoothDeviceName(root.bluetoothConfirmDevice)
                        color: SettingsTokens.fg
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.bluetoothConfirmDevice?.connected
                            ? "This will disconnect the selected device."
                            : "This will pair, trust, and connect the selected device."
                        color: SettingsTokens.muted
                        font.pixelSize: Appearance.font.pixelSize.small
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.bluetoothConfirmDevice?.address ? `Address: ${root.bluetoothConfirmDevice.address}` : "Address unavailable"
                        color: root.bluetoothConfirmDevice?.address ? SettingsTokens.dim : "#f07070"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        elide: Text.ElideRight
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        SettingsButton {
                            label: "Yes"
                            iconName: "check"
                            enabledState: !!root.bluetoothConfirmDevice?.address
                            onClicked: root.confirmBluetoothAction()
                        }

                        SettingsButton {
                            label: "Cancel"
                            iconName: "close"
                            onClicked: root.closeBluetoothConfirm()
                        }
                    }
                }
            }
        }

        Item {
            anchors.fill: parent
            visible: BluetoothStatus.actionRunning && BluetoothStatus.actionPasskey.length > 0
            z: 55

            Rectangle {
                anchors.fill: parent
                color: "#050505"
                opacity: 0.72
            }

            Rectangle {
                width: Math.min(520, parent.width - 64)
                height: 260
                anchors.centerIn: parent
                radius: SettingsTokens.roundRadius
                color: SettingsTokens.card
                border.width: 1
                border.color: SettingsTokens.accent

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    StyledText {
                        Layout.fillWidth: true
                        text: "Bluetooth pairing code"
                        color: SettingsTokens.fg
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: BluetoothStatus.actionPasskey
                        color: SettingsTokens.accent
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: 48
                        font.weight: Font.DemiBold
                        font.letterSpacing: 4
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: "Type this number on the Bluetooth keyboard, then press Enter on that keyboard."
                        color: SettingsTokens.fg
                        font.pixelSize: Appearance.font.pixelSize.small
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: BluetoothStatus.actionDeviceName
                        color: SettingsTokens.muted
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
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
    Component { id: notificationsPageComponent; NotificationsPage { settingsRoot: root } }
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
        id: bluetoothPage
        PageBody {
            // ── Bluetooth Adapter ────────────────────────────────────────
            SettingsCard {
                title: "Bluetooth"
                subtitle: {
                    if (!BluetoothStatus.available) return "Not available"
                    if (!BluetoothStatus.enabled) return "Disabled"
                    if (BluetoothStatus.connected) return `${BluetoothStatus.activeDeviceCount} connected`
                    return "Enabled"
                }

                SettingsToggleRow {
                    label: "Adapter power"
                    description: "Turn Bluetooth on or off"
                    checked: BluetoothStatus.enabled
                    onToggled: {
                        if (Bluetooth.defaultAdapter)
                            Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                    }
                }

                SettingsRow {
                    label: "Connected devices"
                    value: `${BluetoothStatus.activeDeviceCount}`
                    visible: BluetoothStatus.enabled
                }

                ButtonRow {
                    visible: BluetoothStatus.enabled && Bluetooth.defaultAdapter
                    SettingsButton {
                        label: Bluetooth.defaultAdapter.discovering ? "Stop Discovery" : "Start Discovery"
                        iconName: "search"
                        active: Bluetooth.defaultAdapter.discovering
                        onClicked: Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering
                    }
                }
            }

            SettingsCard {
                title: BluetoothStatus.actionRunning ? "Bluetooth Action" : "Last Bluetooth Action"
                subtitle: BluetoothStatus.actionStatus
                visible: BluetoothStatus.actionRunning || BluetoothStatus.actionMessage.length > 0 || BluetoothStatus.actionError.length > 0

                SettingsRow {
                    label: "Device"
                    value: BluetoothStatus.actionDeviceName || "--"
                    description: BluetoothStatus.actionAddress
                    valueColor: BluetoothStatus.actionError.length > 0 ? "#f07070" : SettingsTokens.accent
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: BluetoothStatus.actionPasskey.length > 0 ? 96 : 56
                    radius: SettingsTokens.radius
                    color: BluetoothStatus.actionError.length > 0 ? "#3a2424" : SettingsTokens.panelAlt
                    border.width: 1
                    border.color: BluetoothStatus.actionError.length > 0 ? "#f07070" : SettingsTokens.buttonBorder

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        StyledText {
                            Layout.fillWidth: true
                            text: BluetoothStatus.actionMessage
                            color: BluetoothStatus.actionError.length > 0 ? "#f07070" : SettingsTokens.fg
                            font.pixelSize: Appearance.font.pixelSize.small
                            wrapMode: Text.WordWrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: BluetoothStatus.actionPasskey.length > 0
                            text: BluetoothStatus.actionPasskey
                            color: SettingsTokens.accent
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: 30
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            font.letterSpacing: 2
                        }
                    }
                }
            }

            // ── Devices ──────────────────────────────────────────────────
            SettingsCard {
                title: "Devices"
                subtitle: `${BluetoothStatus.friendlyDeviceList.length} found`
                visible: BluetoothStatus.enabled

                Repeater {
                    model: BluetoothStatus.friendlyDeviceList.slice(0, 15)
                    delegate: Rectangle {
                        id: btDelegate
                        required property var modelData
                        readonly property var device: modelData
                        readonly property bool isConnected: device.connected ?? false
                        readonly property bool isPaired: device.paired ?? false

                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: SettingsTokens.radius
                        color: isConnected ? SettingsTokens.accentSoft : (btMouse.containsMouse ? SettingsTokens.cardHover : "transparent")
                        border.width: isConnected ? 1 : 0
                        border.color: SettingsTokens.accent

                        MouseArea {
                            id: btMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openBluetoothConfirm(device)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            MaterialSymbol {
                                text: {
                                    const name = (device.name || "").toLowerCase()
                                    if (name.includes("headphone") || name.includes("headset") || name.includes("airpods")) return "headphones"
                                    if (name.includes("mouse")) return "mouse"
                                    if (name.includes("keyboard")) return "keyboard"
                                    if (name.includes("phone") || name.includes("iphone")) return "smartphone"
                                    if (name.includes("watch")) return "watch"
                                    if (name.includes("speaker")) return "speaker"
                                    return "bluetooth"
                                }
                                iconSize: 18
                                color: isConnected ? SettingsTokens.accent : SettingsTokens.muted
                                Layout.preferredWidth: 22
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                StyledText {
                                    Layout.fillWidth: true
                                    text: device.name || device.address || "Unknown device"
                                    color: SettingsTokens.fg
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: isConnected ? Font.Medium : Font.Normal
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    text: isConnected ? "Connected" : isPaired ? "Paired" : "Not paired"
                                    color: isConnected ? SettingsTokens.accent : SettingsTokens.dim
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                }
                            }

                            // Connect/disconnect button
                            Rectangle {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                radius: SettingsTokens.radius
                                color: btnMouse.containsMouse ? SettingsTokens.buttonHover : "transparent"

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: isConnected ? "bluetooth_disabled" : "bluetooth"
                                    iconSize: 16
                                    color: isConnected ? "#f07070" : SettingsTokens.accent
                                }

                                MouseArea {
                                    id: btnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        root.openBluetoothConfirm(device)
                                    }
                                }
                            }
                        }
                    }
                }

                // Empty state
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    visible: BluetoothStatus.friendlyDeviceList.length === 0
                    color: "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: "No devices found. Start discovery to search."
                        color: SettingsTokens.dim
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
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
                id: windowsState
                property bool configured: false
                property bool kvm: false
                property bool dockerCli: false
                property bool dockerRunning: false
                property bool compose: false
                property string container: "missing"
                property string web: "http://127.0.0.1:8006"
                property string composeFile: `${FileUtils.trimFileProtocol(Directories.home)}/.config/windows/docker-compose.yml`
                property string storageDir: `${FileUtils.trimFileProtocol(Directories.home)}/.windows`
                property string sharedDir: `${FileUtils.trimFileProtocol(Directories.home)}/Windows`
                property string ram: ""
                property string cpu: ""
                property string disk: ""
                property string user: ""
                property string pendingDanger: ""

                readonly property bool running: container === "running"
                readonly property string displayStatus: !configured ? "Not installed" : running ? "Running" : container === "missing" ? "Configured" : container

                function refresh() {
                    windowsStatusProc.running = true;
                }

                function run(action) {
                    windowsActionProc.command = ["bash", "-c", `$HOME/.config/omd/bin/omd-settings-windows-vm ${action}`];
                    windowsActionProc.running = true;
                }

                function launch(keepAlive) {
                    Quickshell.execDetached(["bash", "-c", `$HOME/.config/omd/bin/omd-settings-windows-vm ${keepAlive ? "launch-keepalive" : "launch"}`]);
                }
            }

            SettingsCard {
                title: "Windows VM"
                subtitle: windowsState.displayStatus

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    SettingsStatusPill { label: windowsState.configured ? "configured" : "not installed"; active: windowsState.configured }
                    SettingsStatusPill { label: windowsState.kvm ? "KVM ready" : "KVM missing"; active: windowsState.kvm; warning: !windowsState.kvm }
                    SettingsStatusPill { label: windowsState.dockerRunning ? "Docker running" : windowsState.dockerCli ? "Docker stopped" : "Docker missing"; active: windowsState.dockerRunning; warning: !windowsState.dockerRunning }
                    SettingsStatusPill { label: windowsState.compose ? "Compose ready" : "Compose missing"; active: windowsState.compose; warning: !windowsState.compose }
                }

                SettingsRow {
                    label: "Container"
                    description: "Docker container: omarchy-windows"
                    value: windowsState.container
                    valueColor: windowsState.running ? SettingsTokens.accent : SettingsTokens.muted
                }
                SettingsRow {
                    label: "Web console"
                    description: "Browser console for installation and emergency access"
                    value: windowsState.web
                    showChevron: true
                    onClicked: windowsState.run("web")
                }
            }

            SettingsCard {
                title: "Actions"
                subtitle: "Large downloads and destructive operations are confirmed"

                ButtonRow {
                    SettingsButton {
                        label: windowsState.configured ? "Reinstall" : "Install"
                        iconName: "download"
                        active: windowsState.pendingDanger === "install"
                        onClicked: {
                            if (windowsState.pendingDanger === "install") {
                                windowsState.pendingDanger = "";
                                Quickshell.execDetached(["bash", "-c", "$HOME/.config/omd/bin/omd-settings-windows-vm install"]);
                            } else {
                                windowsState.pendingDanger = "install";
                            }
                        }
                    }
                    SettingsButton {
                        label: "Connect"
                        iconName: "login"
                        enabledState: windowsState.configured
                        onClicked: windowsState.launch(false)
                    }
                    SettingsButton {
                        label: "Keep Alive"
                        iconName: "keep"
                        enabledState: windowsState.configured
                        onClicked: windowsState.launch(true)
                    }
                }

                ButtonRow {
                    SettingsButton {
                        label: "Stop"
                        iconName: "stop"
                        enabledState: windowsState.configured && windowsState.container !== "missing"
                        onClicked: windowsState.run("stop")
                    }
                    SettingsButton {
                        label: "Open Console"
                        iconName: "open_in_browser"
                        enabledState: windowsState.configured
                        onClicked: windowsState.run("web")
                    }
                    SettingsButton {
                        label: windowsState.pendingDanger === "remove" ? "Confirm Delete" : "Remove"
                        iconName: "delete"
                        active: windowsState.pendingDanger === "remove"
                        enabledState: windowsState.configured
                        onClicked: {
                            if (windowsState.pendingDanger === "remove") {
                                windowsState.pendingDanger = "";
                                Quickshell.execDetached(["bash", "-c", "$HOME/.config/omd/bin/omd-settings-windows-vm remove"]);
                            } else {
                                windowsState.pendingDanger = "remove";
                            }
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: windowsState.pendingDanger.length > 0
                    text: windowsState.pendingDanger === "remove"
                        ? "Remove opens a terminal confirmation and deletes the VM data if confirmed there."
                        : "Install opens an interactive terminal, downloads Windows, and allocates disk space."
                    color: SettingsTokens.muted
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }
            }

            SettingsCard {
                title: "Configuration"
                subtitle: windowsState.configured ? "Generated by omd-windows-vm" : "Created during install"
                SettingsRow { label: "Compose file"; value: windowsState.composeFile }
                SettingsRow { label: "Storage"; value: windowsState.storageDir }
                SettingsRow { label: "Shared folder"; value: windowsState.sharedDir }
                SettingsRow { label: "RAM"; value: windowsState.ram.length > 0 ? windowsState.ram : "--" }
                SettingsRow { label: "CPU cores"; value: windowsState.cpu.length > 0 ? windowsState.cpu : "--" }
                SettingsRow { label: "Disk"; value: windowsState.disk.length > 0 ? windowsState.disk : "--" }
                SettingsRow { label: "Windows user"; value: windowsState.user.length > 0 ? windowsState.user : "--" }
            }

            Timer {
                interval: 8000
                repeat: true
                running: true
                onTriggered: windowsState.refresh()
            }

            Process {
                id: windowsStatusProc
                command: ["bash", "-c", "$HOME/.config/omd/bin/omd-settings-windows-vm status"]
                running: true
                stdout: StdioCollector {
                    id: windowsStatusCollector
                    onStreamFinished: {
                        const data = root.parseKeyValue(windowsStatusCollector.text);
                        windowsState.configured = data.configured === "true";
                        windowsState.kvm = data.kvm === "true";
                        windowsState.dockerCli = data.dockerCli === "true";
                        windowsState.dockerRunning = data.dockerRunning === "true";
                        windowsState.compose = data.compose === "true";
                        windowsState.container = data.container || "missing";
                        windowsState.web = data.web || "http://127.0.0.1:8006";
                        windowsState.composeFile = data.composeFile || windowsState.composeFile;
                        windowsState.storageDir = data.storageDir || windowsState.storageDir;
                        windowsState.sharedDir = data.sharedDir || windowsState.sharedDir;
                        windowsState.ram = data.ram || "";
                        windowsState.cpu = data.cpu || "";
                        windowsState.disk = data.disk || "";
                        windowsState.user = data.user || "";
                    }
                }
            }

            Process {
                id: windowsActionProc
                running: false
                onExited: (exitCode, exitStatus) => windowsState.refresh()
            }
        }
    }
}
