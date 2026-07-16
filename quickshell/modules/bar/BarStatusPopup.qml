pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.schedulePopup.notifications
import qs.modules.settings
import qs.modules.settings.widgets
import qs.services
import qs.services as Services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Wayland
import qs.modules.bar

Scope {
    id: root

    readonly property string activeType: GlobalStates.barPopupType || ""
    readonly property bool open: activeType.length > 0 && !GlobalStates.screenLocked
    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        ?? Quickshell.screens[0]
        ?? null
    // Prefer the bar/screen that opened the popup (multi-monitor), else focused.
    readonly property var popupScreen: {
        const name = GlobalStates.barPopupAnchorScreen || "";
        if (name.length)
            return Quickshell.screens.find(s => s.name === name) ?? focusedScreen;
        return focusedScreen;
    }

    function close() {
        GlobalStates.barPopupEphemeral = false;
        GlobalStates.barPopupType = "";
        GlobalStates.barPopupAnchorScreen = "";
    }

    function openDialog(dialogType) {
        root.close();
        Quickshell.execDetached([`${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-settings`, "open", dialogType]);
    }

    IpcHandler {
        target: "barPopup"

        function toggle(type: string): void {
            GlobalStates.barPopupType = GlobalStates.barPopupType === type ? "" : type;
        }

        function close(): void {
            GlobalStates.barPopupType = "";
        }

        function open(type: string): void {
            GlobalStates.barPopupType = type;
        }
    }

    PanelWindow {
        id: popupWindow
        screen: root.popupScreen
        visible: root.open && root.popupScreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:barstatus"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.activeType === "inputMethod"
            ? WlrKeyboardFocus.None
            : WlrKeyboardFocus.OnDemand

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.close();
                event.accepted = true;
            }
        }

        readonly property bool barOnBottom: Config.options.bar.bottom
        readonly property int panelWidth: {
            if (root.activeType === "battery")
                return Math.min(460, Math.max(420, (screen?.width ?? 1920) - 32));
            if (root.activeType === "notifications")
                return Math.min(560, Math.max(500, (screen?.width ?? 1920) - 32));
            if (root.activeType === "xkb")
                return Math.min(360, Math.max(320, (screen?.width ?? 1920) - 32));
            if (root.activeType === "wifi")
                return Math.min(480, Math.max(440, (screen?.width ?? 1920) - 32));
            if (root.activeType === "audio")
                return Math.min(480, Math.max(440, (screen?.width ?? 1920) - 32));
            // All other panels: 420px minimum for comfortable layout
            return Math.min(460, Math.max(420, (screen?.width ?? 1920) - 32));
        }

        anchors {
            top: !barOnBottom
            bottom: barOnBottom
            right: true
        }

        margins {
            top: barOnBottom ? 0 : Appearance.sizes.barHeight + 4
            bottom: barOnBottom ? Appearance.sizes.barHeight + 4 : 0
            right: 4
        }

        implicitWidth: panel.implicitWidth
        implicitHeight: panel.implicitHeight
        Behavior on implicitHeight { }  // Disable height animation
        Behavior on implicitWidth { }   // Disable width animation

        Timer {
            id: dismissGuard
            interval: 300
            repeat: false
            onTriggered: GlobalFocusGrab.addDismissable(popupWindow)
        }

        onVisibleChanged: {
            if (visible) {
                popupWindow.screen = root.popupScreen;
                dismissGuard.restart();
            } else {
                dismissGuard.stop();
                GlobalFocusGrab.removeDismissable(popupWindow);
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                console.log("[BARPOPUP] onDismissed, screenshotActive=" + BarRuntime.screenshotActive + " activeType=" + root.activeType);
                if (!BarRuntime.screenshotActive) root.close();
            }
        }

        Item {
            id: panel
            anchors.right: parent.right
            // Power panel uses ShellCard chrome; other types use one outer shell.
            readonly property bool multiShell: root.activeType === "battery"
            readonly property real shadowMargin: multiShell ? 0 : Appearance.sizes.elevationMargin
            implicitWidth: panelBg.implicitWidth + shadowMargin * 2
            implicitHeight: panelBg.implicitHeight + shadowMargin * 2
            width: implicitWidth
            height: implicitHeight

            StyledRectangularShadow {
                target: panelBg
                visible: !panel.multiShell
            }

            TuiShell {
                id: panelBg
                anchors.fill: parent
                anchors.margins: panel.shadowMargin
                implicitWidth: popupWindow.panelWidth
                implicitHeight: contentLoader.implicitHeight + contentPadding * 2
                contentPadding: 0                           // Rows manage their own 20px margins
                // Height-variable content (audio expand, etc.): skip OpacityMask FBO
                // rebuild on resize — see docs/bar-popup-height-stability.md.
                useLayerMask: false
                color: panel.multiShell ? "transparent" : TuiStyle.bg
                border.width: panel.multiShell ? 0 : TuiStyle.borderWidth
                border.color: TuiStyle.menuBorder
                radius: panel.multiShell ? 0 : TuiStyle.shellRadius
                clip: !panel.multiShell

                Loader {
                    id: contentLoader
                    anchors.fill: parent
                    sourceComponent: {
                        if (root.activeType === "wifi") return wifiContent;
                        if (root.activeType === "bluetooth") return bluetoothContent;
                        if (root.activeType === "audio") return audioContent;
                        if (root.activeType === "display") return displayContent;
                        if (root.activeType === "battery") return batteryContent;
                        if (root.activeType === "notifications") return notificationsContent;
                        if (root.activeType === "voice") return voiceContent;
                        if (root.activeType === "inputMethod") return inputMethodContent;
                        if (root.activeType === "keyboard") return keyboardContent;
                        if (root.activeType === "session") return sessionContent;
                        if (root.activeType === "xkb") return xkbContent;
                        if (root.activeType === "tools") return toolsContent;
                        return emptyContent;
                    }
                }
            }
        }
    }

    component PopupColumn: ColumnLayout {
        spacing: 0
        width: parent?.width ?? implicitWidth
    }

    component ToolLauncherRow: SettingsNavigationRow {
        id: toolRow

        property string icon: ""
        property string title: ""
        property string subtitle: ""
        iconName: icon
        label: title
        description: subtitle
    }

    // Stacked card chrome — same tokens as BarContextMenu (bg / shellBorder / shellRadius).
    component ShellCard: Item {
        id: card
        default property alias content: cardColumn.data
        property int padding: 14
        property int gap: Appearance.sizes.elevationMargin
        property int gapTop: gap
        property int gapBottom: gap

        Layout.fillWidth: true
        implicitWidth: parent?.width ?? 0
        implicitHeight: visible ? (cardBg.implicitHeight + gapTop + gapBottom) : 0
        height: implicitHeight
        visible: true

        StyledRectangularShadow {
            target: cardBg
            visible: card.visible
        }

        Rectangle {
            id: cardBg
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: card.gap
                rightMargin: card.gap
                topMargin: card.gapTop
                bottomMargin: card.gapBottom
            }
            color: TuiStyle.bg
            radius: TuiStyle.shellRadius
            border.width: TuiStyle.borderWidth   // Unified border
            border.color: TuiStyle.menuBorder
            clip: true
            implicitHeight: cardColumn.implicitHeight + card.padding * 2
            height: implicitHeight

            ColumnLayout {
                id: cardColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: card.padding
                }
                spacing: 0
            }
        }
    }

    // Thin section divider — extremely subtle, GNOME style.
    component Divider: Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: TuiStyle.line
        opacity: TuiStyle.dividerOpacity
    }

    // Section label (small dim caps) — kept for compact sub-headings.
    component SectionLabel: StyledText {
        property int topInset: 6
        property int bottomInset: 2
        Layout.fillWidth: true
        Layout.topMargin: topInset
        Layout.bottomMargin: bottomInset
        font.family: Appearance.font.family.monospace
        font.pixelSize: Appearance.font.pixelSize.smaller
        font.weight: Font.Bold
        color: TuiStyle.dim
    }

    // Action row — right-aligned button cluster.
    component ActionRow: RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        spacing: 8
        Item { Layout.fillWidth: true }
    }

    component PopupActionButton: SettingsButton {
        Layout.fillWidth: false
        Layout.preferredWidth: 120
    }

    // Icon action row — full-width evenly-spaced icon buttons.
    // Each child should be a PopupIconButton.
    component IconActionRow: Item {
        Layout.fillWidth: true
        Layout.leftMargin: 20
        Layout.rightMargin: 20
        Layout.topMargin: 4
        Layout.bottomMargin: 8
        implicitHeight: iconRowInner.implicitHeight

        RowLayout {
            id: iconRowInner
            anchors { left: parent.left; right: parent.right }
            spacing: 8
        }

        default property alias buttons: iconRowInner.data
    }

    // Individual icon button for IconActionRow.
    component PopupIconButton: Item {
        id: iconBtn
        property string icon: ""
        property string label: ""
        property color accent: SettingsTokens.fg
        property bool enabledState: true
        signal clicked()

        Layout.fillWidth: true
        implicitHeight: 60
        opacity: iconBtn.enabledState ? 1.0 : 0.38

        Rectangle {
            id: iconBtnBg
            anchors.fill: parent
            radius: SettingsTokens.radius
            color: iconBtnMouse.containsMouse && iconBtn.enabledState
                ? SettingsTokens.buttonHover : SettingsTokens.button
            border.width: 1
            border.color: SettingsTokens.buttonBorder

            Behavior on color { ColorAnimation { duration: 100 } }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4

                NerdIcon {
                    Layout.alignment: Qt.AlignHCenter
                    iconSize: 20
                    text: iconBtn.icon
                    color: iconBtn.accent
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: iconBtn.label
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small - 1
                    font.weight: Font.Medium
                    color: SettingsTokens.muted
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        MouseArea {
            id: iconBtnMouse
            anchors.fill: parent
            enabled: iconBtn.enabledState
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: iconBtn.clicked()
        }
    }

    function adjustOutputVolumeFromWheel(wheel, accumHolder) {
        GlobalStates.barPopupEphemeral = false;
        const r = WheelUtils.getSteps(wheel.angleDelta.y, accumHolder.wheelAccum)
        accumHolder.wheelAccum = r.accum
        for (let i = 0; i < Math.abs(r.steps); i++) {
            if (r.steps > 0)
                Audio.incrementVolume()
            else if (r.steps < 0)
                Audio.decrementVolume()
        }
        wheel.accepted = true
    }

    Component {
        id: emptyContent
        Item { implicitHeight: 1 }
    }

    Component {
        id: toolsContent
        PopupColumn {
            PopupHeader {
                Layout.fillWidth: true
                icon: NerdIconMap.wrench
                title: "OMD Tools"
                subtitle: "Advanced desktop tools"
            }

            ToolLauncherRow {
                icon: "palette"
                title: "Themes"
                subtitle: "Colors, fonts and desktop appearance"
                onClicked: root.openDialog("appearance")
            }

            ToolLauncherRow {
                icon: "keyboard_voice"
                title: "Voice Input"
                subtitle: "Speech engine, model and shortcuts"
                onClicked: root.openDialog("voice")
            }

            ToolLauncherRow {
                icon: "keyboard"
                title: "Keyboard Remap"
                subtitle: "Devices, profiles and key mappings"
                onClicked: root.openDialog("keyremap")
            }

            ToolLauncherRow {
                icon: "desktop_windows"
                title: "Windows VM"
                subtitle: "Install, run and manage Windows"
                onClicked: root.openDialog("windows")
            }
        }
    }

    Component {
        id: inputMethodContent
        PopupColumn {
            id: inputMethodPanel

            property var choices: [
                { schema: "sbzr", badge: "中", title: "Chinese", subtitle: "Natural input" },
                { schema: "sbzr_mix", badge: "混", title: "Chinese", subtitle: "Mixed input" },
                { schema: "easy_en", badge: "A", title: "English", subtitle: "Easy English" },
                { schema: "jaroomaji", badge: "あ", title: "Japanese", subtitle: "Romaji" }
            ]

            Component.onCompleted: Services.InputMethod.refresh()

            PopupHeader {
                Layout.fillWidth: true
                icon: NerdIconMap.keyboard
                title: "Input Language"
                subtitle: Services.InputMethod.available ? Services.InputMethod.summary : "Fcitx5 is unavailable"
                tone: Services.InputMethod.available ? TuiStyle.accent : TuiStyle.danger
                showDivider: true
            }

            Repeater {
                model: inputMethodPanel.choices

                delegate: Rectangle {
                    id: languageRow
                    required property var modelData
                    readonly property bool selected: Services.InputMethod.schema === modelData.schema

                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
                    color: selected ? TuiStyle.panelAlt
                        : languageMouse.containsMouse ? TuiStyle.surfaceHover
                        : "transparent"
                    radius: TuiStyle.miniRadius

                    MouseArea {
                        id: languageMouse
                        anchors.fill: parent
                        enabled: !Services.InputMethod.busy
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const returnAddress = HyprlandData.activeWindow?.address || "";
                            root.close();
                            Services.InputMethod.selectSchema(languageRow.modelData.schema, returnAddress);
                        }
                    }

                    Rectangle {
                        id: languageBadge
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        height: 30
                        radius: TuiStyle.miniRadius
                        color: languageRow.selected ? TuiStyle.accent : TuiStyle.surfaceSubtle

                        StyledText {
                            anchors.centerIn: parent
                            text: languageRow.modelData.badge
                            color: languageRow.selected ? TuiStyle.bg : TuiStyle.fg
                            font.family: Appearance.font.family.main
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }
                    }

                    Column {
                        anchors.left: languageBadge.right
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        StyledText {
                            text: languageRow.modelData.title
                            color: TuiStyle.fg
                            font.family: Appearance.font.family.main
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: languageRow.selected ? Font.DemiBold : Font.Normal
                        }

                        StyledText {
                            text: languageRow.modelData.subtitle
                            color: TuiStyle.dim
                            font.family: Appearance.font.family.main
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }

                    NerdIcon {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        iconSize: 15
                        text: Services.InputMethod.busy && languageRow.selected
                            ? NerdIconMap.refresh
                            : NerdIconMap.check
                        color: TuiStyle.accent
                        visible: languageRow.selected
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                visible: Services.InputMethod.lastError.length > 0
                text: "Unable to switch input language"
                color: TuiStyle.danger
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.Wrap
            }

            PopupFooterLink {
                Layout.fillWidth: true
                label: "Fcitx configuration…"
                onClicked: {
                    root.close();
                    Services.InputMethod.openConfiguration();
                }
            }
        }
    }

    Component {
        id: keyboardContent
        PopupColumn {
            id: keyboardPanel

            function stateLabel() {
                if (KeyboardRemap.state === "setup") return "Setup needed";
                if (!KeyboardRemap.keydReady) return "keyd not running";
                if (KeyboardRemap.selectedDeviceId) return "Ready";
                return "No device";
            }
            function tone() {
                if (stateLabel() === "Ready") return TuiStyle.success;
                if (stateLabel() === "Setup needed" || stateLabel() === "keyd not running") return TuiStyle.danger;
                return TuiStyle.muted;
            }

            PopupHeader {
                Layout.fillWidth: true
                icon: NerdIconMap.keyboard
                title: "Keyboard"
                subtitle: keyboardPanel.stateLabel()
                tone: keyboardPanel.tone()
            }

            PopupInfoRow { label: "Device"; value: KeyboardRemap.selectedDeviceId || "--"; valueColor: KeyboardRemap.selectedDeviceId ? TuiStyle.fg : TuiStyle.dim }
            PopupInfoRow { label: "Keyd"; value: KeyboardRemap.keydReady ? "Running" : "Not ready"; valueColor: KeyboardRemap.keydReady ? TuiStyle.success : TuiStyle.danger }
            PopupInfoRow {
                label: "Profile"
                value: KeyboardRemap.selectedProfile?.displayName || "--"
                valueColor: KeyboardRemap.selectedProfile ? TuiStyle.accent : TuiStyle.dim
                showDivider: false
            }

            PopupFooterLink {
                Layout.fillWidth: true
                label: "Keyboard settings…"
                onClicked: { root.close(); KeyboardRemap.openSettings(); }
            }
        }
    }

    Component {
        id: sessionContent
        PopupColumn {
            id: sessionPanel
            readonly property string omdSession: `${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-session`
            readonly property string snapshotFile: `${FileUtils.trimFileProtocol(Directories.home)}/.local/state/omd/session/last.json`
            property bool hasSnapshot: false
            property int snapshotCount: 0
            property bool canvasEmpty: ToplevelManager.toplevels.values.length === 0

            FileView {
                path: sessionPanel.snapshotFile
                onLoaded: {
                    try {
                        const data = JSON.parse(text());
                        const count = Array.isArray(data.clients) ? data.clients.length : 0;
                        sessionPanel.hasSnapshot = count > 0;
                        sessionPanel.snapshotCount = count;
                    } catch (e) {
                        sessionPanel.hasSnapshot = false;
                        sessionPanel.snapshotCount = 0;
                    }
                }
                onLoadFailed: {
                    sessionPanel.hasSnapshot = false;
                    sessionPanel.snapshotCount = 0;
                }
            }

            PopupHeader {
                Layout.fillWidth: true
                icon: NerdIconMap.workspaceSnapshot
                title: "Session"
                subtitle: sessionPanel.canvasEmpty ? "No windows open"
                    : `${ToplevelManager.toplevels.values.length} window${ToplevelManager.toplevels.values.length === 1 ? "" : "s"} open`
                tone: sessionPanel.canvasEmpty ? TuiStyle.muted : TuiStyle.success
            }

            PopupInfoRow {
                label: "Saved snapshot"
                value: sessionPanel.hasSnapshot ? `${sessionPanel.snapshotCount} windows` : "None"
                valueColor: sessionPanel.hasSnapshot ? TuiStyle.accent : TuiStyle.dim
                showDivider: false
            }

            IconActionRow {
                PopupIconButton {
                    icon: NerdIconMap.workspaceSnapshot
                    label: sessionPanel.canvasEmpty ? "Snapshot" : "Snapshot"
                    accent: TuiStyle.info
                    enabledState: !sessionPanel.canvasEmpty || sessionPanel.hasSnapshot
                    onClicked: { root.close(); Quickshell.execDetached([sessionPanel.omdSession, "save"]); }
                }
                PopupIconButton {
                    icon: NerdIconMap.refresh
                    label: "Restore"
                    accent: TuiStyle.accent
                    enabledState: sessionPanel.hasSnapshot
                    onClicked: { root.close(); Quickshell.execDetached([sessionPanel.omdSession, "restore"]); }
                }
                PopupIconButton {
                    icon: NerdIconMap.close
                    label: "Clear"
                    accent: TuiStyle.danger
                    enabledState: sessionPanel.hasSnapshot
                    onClicked: { root.close(); Quickshell.execDetached([sessionPanel.omdSession, "clear"]); }
                }
            }
        }
    }

    Component {
        id: xkbContent
        PopupColumn {
            id: xkbPanel
            property list<string> layouts: HyprlandXkb.layoutCodes

            PopupHeader {
                Layout.fillWidth: true
                icon: NerdIconMap.keyboard
                title: "Keyboard Layout"
                subtitle: HyprlandXkb.currentLayoutName || "Unknown layout"
                tone: TuiStyle.accent
                showDivider: true
            }

            Repeater {
                model: xkbPanel.layouts
                delegate: Rectangle {
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: modelData === HyprlandXkb.currentLayoutName ? TuiStyle.panelAlt
                        : layoutMouse.containsMouse ? TuiStyle.surfaceHover
                        : "transparent"
                    radius: TuiStyle.miniRadius

                    MouseArea {
                        id: layoutMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", `${xkbPanel.layouts.indexOf(modelData)}`]);
                            root.close();
                        }
                    }

                    StyledText {
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: modelData === HyprlandXkb.currentLayoutName ? Font.DemiBold : Font.Normal
                        color: modelData === HyprlandXkb.currentLayoutName ? TuiStyle.fg : TuiStyle.dim
                    }

                    NerdIcon {
                        anchors.right: parent.right; anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        iconSize: 14
                        text: NerdIconMap.check
                        color: TuiStyle.accent
                        visible: modelData === HyprlandXkb.currentLayoutName
                    }
                }
            }
        }
    }

    Component {
        id: wifiContent
        PopupColumn {
            id: wifiPanel

            Component.onCompleted: {
                if (Network.wifiEnabled)
                    Network.rescanWifi();
            }

            function pinOpen() {
                GlobalStates.barPopupEphemeral = false;
            }

            function connStatus() {
                if (Network.wifiConnectPhase === "connecting" || Network.wifiConnecting)
                    return "Connecting";
                if (Network.wifiConnectPhase === "need_password")
                    return "Password";
                if (Network.wifiConnectPhase === "failed")
                    return "Failed";
                if (Network.ethernet)
                    return "Connected";
                if (!Network.wifiEnabled || Network.wifiStatus === "disabled")
                    return "Disabled";
                const s = Network.wifiStatus || "disconnected";
                return s.charAt(0).toUpperCase() + s.slice(1);
            }
            function connTone() {
                const s = wifiPanel.connStatus();
                if (s === "Connected" || Network.wifiConnectPhase === "success")
                    return TuiStyle.success;
                if (s === "Disabled" || s === "Failed")
                    return TuiStyle.danger;
                if (s === "Connecting" || s === "Limited" || s === "Password")
                    return TuiStyle.warning;
                return TuiStyle.muted;
            }
            function connIcon() {
                return Network.ethernet ? NerdIconMap.ethernet : NerdIconMap.wifi;
            }
            function connName() {
                if (Network.ethernet)
                    return Network.networkName || "Wired Connection";
                return Network.active?.ssid || Network.networkName || "Not connected";
            }
            function connDetail() {
                if (Network.wifiConnectMessage.length > 0
                        && Network.wifiConnectPhase !== "idle"
                        && Network.wifiConnectPhase !== "success")
                    return Network.wifiConnectMessage;
                if (Network.ethernet)
                    return "";
                if (Network.wifiStatus === "connected")
                    return `Signal ${Network.active?.strength ?? Network.networkStrength}%  ·  ${Network.friendlyWifiNetworks.length} nearby`;
                return `${Network.friendlyWifiNetworks.length} network${Network.friendlyWifiNetworks.length === 1 ? "" : "s"} nearby`;
            }



            // ── Wi-Fi section: toggle + nearby list ──
            PopupToggleRow {
                label: "Wi-Fi"
                checked: Network.wifiEnabled
                showSettingsButton: true
                showDivider: false
                onToggled: checked => {
                    wifiPanel.pinOpen();
                    Network.enableWifi(checked);
                }
                onSettingsClicked: root.openDialog("wifi")
            }

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                Layout.topMargin: 2
                Layout.bottomMargin: 4
                visible: Network.wifiEnabled
                    && Network.wifiConnectMessage.length > 0
                    && Network.wifiConnectPhase !== "idle"
                text: Network.wifiConnectMessage
                color: Network.wifiConnectPhase === "failed" || Network.wifiConnectPhase === "need_password"
                    ? TuiStyle.danger
                    : (Network.wifiConnectPhase === "success" ? TuiStyle.success : TuiStyle.muted)
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 12
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                visible: Network.wifiEnabled
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    text: Network.wifiScanning ? "Scanning…" : "Networks"
                    color: TuiStyle.dim
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 4
                    color: wifiScanMouse.containsMouse ? TuiStyle.controlHover : "transparent"

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "refresh"
                        iconSize: 16
                        color: TuiStyle.muted
                        RotationAnimator on rotation {
                            running: Network.wifiScanning
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 1200
                        }
                    }

                    MouseArea {
                        id: wifiScanMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            wifiPanel.pinOpen();
                            Network.rescanWifi();
                        }
                    }
                }
            }

            Flickable {
                id: wifiListFlick
                Layout.fillWidth: true
                Layout.preferredHeight: Network.wifiEnabled
                    ? Math.min(wifiListCol.implicitHeight, 280)
                    : 0
                visible: Network.wifiEnabled
                contentHeight: wifiListCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: wifiListCol.implicitHeight > height

                ColumnLayout {
                    id: wifiListCol
                    width: wifiListFlick.width
                    spacing: 0

                    Repeater {
                        model: Network.friendlyWifiNetworks.filter(ap => ap.active || Network.isKnownWifi(ap)).slice(0, 12)
                        delegate: ColumnLayout {
                            id: apRow
                            required property var modelData
                            readonly property var ap: modelData
                            readonly property bool isActive: ap.active ?? false
                            readonly property bool isKnown: Network.isKnownWifi(ap)
                            readonly property bool isConnecting: Network.isConnectingTo(ap)
                            readonly property bool showPassword: ap.askingPassword === true

                            Layout.fillWidth: true
                            spacing: 0
                            visible: (ap.ssid || "").length > 0

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                color: apRow.isActive
                                    ? Qt.rgba(TuiStyle.accent.r, TuiStyle.accent.g, TuiStyle.accent.b, 0.12)
                                    : (apMouse.containsMouse ? TuiStyle.surfaceHover : "transparent")

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 20
                                    anchors.rightMargin: 16
                                    spacing: 10

                                    MaterialSymbol {
                                        text: {
                                            if (apRow.isConnecting)
                                                return "progress_activity";
                                            const s = apRow.ap.strength ?? 0;
                                            if (s >= 75)
                                                return "wifi";
                                            if (s >= 50)
                                                return "network_wifi_3_bar";
                                            if (s >= 25)
                                                return "network_wifi_2_bar";
                                            if (s > 0)
                                                return "network_wifi_1_bar";
                                            return "wifi_off";
                                        }
                                        iconSize: 18
                                        color: apRow.isActive ? TuiStyle.accent : TuiStyle.muted
                                        Layout.preferredWidth: 22
                                        RotationAnimator on rotation {
                                            running: apRow.isConnecting
                                            loops: Animation.Infinite
                                            from: 0
                                            to: 360
                                            duration: 1200
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: apRow.ap.ssid || "Hidden"
                                            color: TuiStyle.fg
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            font.weight: apRow.isActive ? Font.DemiBold : Font.Normal
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: {
                                                if (apRow.isActive)
                                                    return "Connected";
                                                if (apRow.isConnecting)
                                                    return "Connecting…";
                                                if (apRow.showPassword)
                                                    return "Enter password";
                                                if (apRow.isKnown)
                                                    return "Saved";
                                                return apRow.ap.isSecure ? "Secured" : "Open";
                                            }
                                            color: TuiStyle.dim
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MaterialSymbol {
                                        visible: apRow.ap.isSecure
                                        text: "lock"
                                        iconSize: 14
                                        color: TuiStyle.dim
                                    }

                                    StyledText {
                                        text: `${apRow.ap.strength ?? 0}%`
                                        color: TuiStyle.muted
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        Layout.preferredWidth: 34
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }

                                MouseArea {
                                    id: apMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: apRow.isActive ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    enabled: !apRow.isActive && !apRow.isConnecting
                                    onClicked: {
                                        wifiPanel.pinOpen();
                                        if (apRow.ap.ssid)
                                            Network.connectToWifiNetwork(apRow.ap);
                                    }
                                }
                            }

                            Rectangle {
                                visible: apRow.showPassword
                                Layout.fillWidth: true
                                Layout.leftMargin: 16
                                Layout.rightMargin: 16
                                Layout.bottomMargin: 8
                                implicitHeight: popupPassCol.implicitHeight + 14
                                radius: 6
                                color: TuiStyle.panel
                                border.width: 1
                                border.color: TuiStyle.line

                                ColumnLayout {
                                    id: popupPassCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 8
                                    spacing: 6

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 34
                                        radius: 4
                                        color: TuiStyle.control
                                        border.width: 1
                                        border.color: popupPassField.activeFocus ? TuiStyle.accent : TuiStyle.line

                                        TextInput {
                                            id: popupPassField
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            verticalAlignment: Text.AlignVCenter
                                            color: TuiStyle.fg
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            echoMode: TextInput.Password
                                            passwordCharacter: "•"
                                            clip: true
                                            focus: apRow.showPassword
                                            enabled: !Network.wifiConnecting
                                            Keys.onReturnPressed: {
                                                wifiPanel.pinOpen();
                                                Network.connectToWifiNetworkWithPassword(apRow.ap, popupPassField.text);
                                            }
                                            Keys.onEnterPressed: {
                                                wifiPanel.pinOpen();
                                                Network.connectToWifiNetworkWithPassword(apRow.ap, popupPassField.text);
                                            }
                                            Keys.onEscapePressed: Network.cancelWifiPassword()
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        SettingsButton {
                                            Layout.fillWidth: true
                                            label: Network.wifiConnecting ? "…" : "Connect"
                                            iconName: "link"
                                            active: true
                                            enabledState: !Network.wifiConnecting && popupPassField.text.length > 0
                                            onClicked: {
                                                wifiPanel.pinOpen();
                                                Network.connectToWifiNetworkWithPassword(apRow.ap, popupPassField.text);
                                            }
                                        }
                                        SettingsButton {
                                            Layout.fillWidth: true
                                            label: "Cancel"
                                            iconName: "close"
                                            enabledState: !Network.wifiConnecting
                                            onClicked: Network.cancelWifiPassword()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 20
                        Layout.rightMargin: 20
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                        visible: Network.friendlyWifiNetworks.length === 0 && !Network.wifiScanning
                        text: "No networks found. Tap refresh to scan."
                        color: TuiStyle.dim
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // ── Wi-Fi advanced footer ──
            PopupFooterLink {
                Layout.fillWidth: true
                label: "Add new Wi-Fi…"
                onClicked: {
                    root.close();
                    Quickshell.execDetached(["/bin/bash", "-c", `${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-launch-wifi`]);
                }
            }

            // Divider between Wi-Fi block and Bluetooth
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: 4
                color: TuiStyle.line
                opacity: TuiStyle.dividerOpacity
            }

            // ── Bluetooth section (standalone) ──
            PopupToggleRow {
                label: "Bluetooth"
                checked: BluetoothStatus.enabled
                enabled: BluetoothStatus.available
                showSettingsButton: true
                showDivider: false
                onToggled: checked => {
                    wifiPanel.pinOpen();
                    if (Bluetooth.defaultAdapter)
                        Bluetooth.defaultAdapter.enabled = checked;
                }
                onSettingsClicked: root.openDialog("bluetooth")
            }

            // ── Bluetooth saved devices list ──
            ColumnLayout {
                id: btListCol
                Layout.fillWidth: true
                spacing: 0
                visible: BluetoothStatus.enabled && btRepeater.count > 0

                Repeater {
                    id: btRepeater
                    model: {
                        const list = [];
                        if (BluetoothStatus.connectedDevices) {
                            for (let i = 0; i < BluetoothStatus.connectedDevices.length; i++) {
                                list.push(BluetoothStatus.connectedDevices[i]);
                            }
                        }
                        if (BluetoothStatus.pairedButNotConnectedDevices) {
                            for (let i = 0; i < BluetoothStatus.pairedButNotConnectedDevices.length; i++) {
                                list.push(BluetoothStatus.pairedButNotConnectedDevices[i]);
                            }
                        }
                        return list.slice(0, 5); // limit to 5 saved devices to save space
                    }

                    delegate: Rectangle {
                        id: btRow
                        required property var modelData
                        readonly property var dev: modelData
                        readonly property bool isActive: dev.connected ?? false
                        readonly property bool isConnecting: BluetoothStatus.actionRunning && BluetoothStatus.actionAddress === dev.address

                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        color: btMouse.containsMouse ? TuiStyle.surfaceHover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 16
                            spacing: 10

                            MaterialSymbol {
                                text: btRow.isConnecting ? "progress_activity" : (btRow.isActive ? "bluetooth_connected" : "bluetooth")
                                iconSize: 18
                                color: btRow.isActive ? TuiStyle.accent : TuiStyle.muted
                                Layout.preferredWidth: 22

                                RotationAnimator on rotation {
                                    running: btRow.isConnecting
                                    loops: Animation.Infinite
                                    from: 0
                                    to: 360
                                    duration: 1200
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: btRow.dev.name || btRow.dev.address || "Unknown Device"
                                    color: TuiStyle.fg
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: btRow.isActive ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: btRow.isConnecting ? "Connecting…" : (btRow.isActive ? "Connected" : "Saved")
                                    color: TuiStyle.dim
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    elide: Text.ElideRight
                                    visible: btRow.isConnecting || btRow.isActive
                                }
                            }
                        }

                        MouseArea {
                            id: btMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wifiPanel.pinOpen();
                                BluetoothStatus.connectDevice(btRow.dev);
                            }
                        }
                    }
                }
            }

            // ── Bluetooth TUI link ──
            PopupFooterLink {
                Layout.fillWidth: true
                visible: BluetoothStatus.enabled
                label: "Add new Bluetooth…"
                onClicked: {
                    root.close();
                    Quickshell.execDetached(["/bin/bash", "-c", `${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-launch-bluetooth`]);
                }
            }
        }
    }

    Component {
        id: bluetoothContent
        PopupColumn {
            id: bluetoothPanel
            function stateLabel() {
                if (!BluetoothStatus.available) return "Unavailable";
                if (!BluetoothStatus.enabled) return "Off";
                if (BluetoothStatus.connected) return "Connected";
                return "On";
            }
            function tone() {
                if (stateLabel() === "Connected") return TuiStyle.success;
                if (stateLabel() === "Off" || stateLabel() === "Unavailable") return TuiStyle.danger;
                return TuiStyle.muted;
            }

            PopupHeader {
                Layout.fillWidth: true
                icon: NerdIconMap.bluetooth
                title: "Bluetooth"
                subtitle: `${stateLabel()}  ·  ${BluetoothStatus.activeDeviceCount} connected`
                tone: tone()
            }

            PopupToggleRow {
                label: "Bluetooth"
                checked: BluetoothStatus.enabled
                enabled: BluetoothStatus.available
                showSettingsButton: true
                onToggled: checked => { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = checked }
                onSettingsClicked: Quickshell.execDetached(["/bin/bash", "-c", `${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-launch-bluetooth`])
                showDivider: false
            }

            PopupFooterLink {
                Layout.fillWidth: true
                label: "Bluetooth pairing TUI…"
                onClicked: Quickshell.execDetached(["/bin/bash", "-c", `${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-launch-bluetooth`])
            }
        }
    }

    Component {
        id: audioContent
        Item {
            id: audioPanel
            width: parent?.width ?? implicitWidth
            implicitWidth: audioColumn.implicitWidth
            implicitHeight: audioColumn.implicitHeight

            property real wheelAccum: 0
            readonly property PwNode sink: Pipewire.defaultAudioSink
            readonly property PwNode source: Pipewire.defaultAudioSource
            readonly property real sinkVolume: sink?.audio.volume ?? 0
            readonly property real sourceVolume: source?.audio.volume ?? 0
            readonly property bool sinkMuted: sink?.audio.muted ?? false
            readonly property bool sourceMuted: source?.audio.muted ?? false
            readonly property MprisPlayer activePlayer: MprisController.activePlayer
            // The controller exposes only Playing or Paused sessions. Stopped
            // and destroyed sessions resolve to null and remove this strip.
            readonly property bool showMediaControls: activePlayer !== null
            readonly property bool hasTrackArt: showMediaControls && TrackArt.resolvedArtUrl.length > 0
            readonly property string trackTitle: {
                const t = StringUtils.cleanMusicTitle(activePlayer?.trackTitle || "")
                return t.length > 0 ? t : "Untitled"
            }
            readonly property string trackArtist: {
                const artist = activePlayer?.trackArtist || ""
                return artist === "Unknown Artist" ? "" : artist
            }
            readonly property bool isPlaying: activePlayer?.playbackState === MprisPlaybackState.Playing
            readonly property string playerName: MprisController.playerIdentity(activePlayer)
            readonly property bool chromiumPlayer: {
                const identity = (activePlayer?.identity || "").toLowerCase()
                return identity.includes("chrome") || identity.includes("chromium")
            }
            readonly property bool usePlayerVolume: !!activePlayer
                && activePlayer.volumeSupported
                && !chromiumPlayer
            readonly property bool mediaMuted: usePlayerVolume
                ? activePlayer.volume <= 0.001
                : sinkMuted
            property real mediaRestoreVolume: 1
            readonly property string mediaSubtitle: {
                if (audioPanel.trackArtist.length > 0)
                    return audioPanel.trackArtist
                if (audioPanel.playerName.length > 0)
                    return audioPanel.playerName
                return audioPanel.isPlaying ? "Playing" : "Paused"
            }

            function pinOpen() { GlobalStates.barPopupEphemeral = false; }
            function setSinkVolume(value) { audioPanel.pinOpen(); Audio.setSinkVolume(value); }
            function setSourceVolume(value) { audioPanel.pinOpen(); Audio.setSourceVolume(value); }
            function mediaPrev() {
                audioPanel.pinOpen()
                MprisController.previousOrRewind()
            }
            function mediaToggle() {
                audioPanel.pinOpen()
                activePlayer?.togglePlaying()
            }
            function mediaNext() {
                audioPanel.pinOpen()
                activePlayer?.next()
            }
            function toggleMediaMute() {
                audioPanel.pinOpen()
                if (!audioPanel.usePlayerVolume) {
                    Audio.toggleMute()
                    return
                }
                const volume = audioPanel.activePlayer.volume
                if (volume > 0.001) {
                    audioPanel.mediaRestoreVolume = volume
                    audioPanel.activePlayer.volume = 0
                } else {
                    audioPanel.activePlayer.volume = Math.max(0.01, audioPanel.mediaRestoreVolume)
                }
            }
            function focusMediaPlayer() {
                root.close()
                Qt.callLater(() => MprisController.raiseActivePlayer())
            }

            ColumnLayout {
                id: audioColumn
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0

                // ── Combined Header (Volume & Media Player) ─────────────────
                Item {
                    id: audioHeader
                    Layout.fillWidth: true
                    implicitHeight: 72

                    RowLayout {
                        id: headerRow
                        anchors {
                            fill: parent
                            leftMargin: 20
                            rightMargin: 16
                        }
                        spacing: 12

                        // Left Side: Album Art (if media playing and has art) or Volume Icon (if not)
                        Item {
                            Layout.preferredWidth: audioPanel.hasTrackArt ? 40 : 26
                            Layout.preferredHeight: audioPanel.hasTrackArt ? 40 : 26
                            Layout.alignment: Qt.AlignVCenter

                            // Case A: Media Artwork (only visible when media playing and has art)
                            Rectangle {
                                anchors.fill: parent
                                visible: audioPanel.hasTrackArt
                                radius: 8
                                color: TuiStyle.surfaceSubtle
                                border.width: 1
                                border.color: TuiStyle.line
                                clip: true

                                Image {
                                    id: headerArtworkImage
                                    anchors.fill: parent
                                    source: TrackArt.resolvedArtUrl
                                    asynchronous: true
                                    cache: true
                                    fillMode: Image.PreserveAspectCrop
                                }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    visible: headerArtworkImage.status !== Image.Ready
                                    text: "album"
                                    iconSize: 22
                                    color: TuiStyle.dim
                                }

                                // Play pulse dot
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 2
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: audioPanel.isPlaying ? TuiStyle.accent : TuiStyle.dim
                                    border.width: 1
                                    border.color: TuiStyle.bg

                                    SequentialAnimation on opacity {
                                        running: audioPanel.isPlaying && audioPanel.hasTrackArt
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 1.0; to: 0.35; duration: 900 }
                                        NumberAnimation { from: 0.35; to: 1.0; duration: 900 }
                                    }
                                }
                            }

                            // Case B: Simple Volume Icon (visible when no media playing OR has no art)
                            NerdIcon {
                                anchors.centerIn: parent
                                visible: !audioPanel.hasTrackArt
                                iconSize: 26
                                text: audioPanel.sinkMuted ? NerdIconMap.volumeOff : NerdIconMap.volumeHigh
                                color: TuiStyle.fg
                            }
                        }

                        // Center: Text Column
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 1

                            // Title: Song Title (if media playing) or "Volume" (if not)
                            StyledText {
                                Layout.fillWidth: true
                                text: audioPanel.showMediaControls ? audioPanel.trackTitle : "Volume"
                                font.family: Appearance.font.family.main
                                font.pixelSize: Appearance.font.pixelSize.normal + (audioPanel.showMediaControls ? 0 : 1)
                                font.weight: Font.Medium
                                color: (audioPanel.showMediaControls && headerTitleMouse.containsMouse) ? TuiStyle.accent : TuiStyle.fg
                                elide: Text.ElideRight

                                MouseArea {
                                    id: headerTitleMouse
                                    anchors.fill: parent
                                    enabled: audioPanel.showMediaControls
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: audioPanel.focusMediaPlayer()
                                }
                            }

                            // Subtitle: Artist + Volume (if media playing) or Volume + Mute details (if not)
                            StyledText {
                                Layout.fillWidth: true
                                text: {
                                    if (audioPanel.showMediaControls) {
                                        const volStr = `${Math.round(audioPanel.sinkVolume * 100)}%`
                                        const extra = audioPanel.sinkMuted ? " (Muted)" : ""
                                        return (audioPanel.mediaSubtitle ? `${audioPanel.mediaSubtitle}  ·  ` : "") + `Vol ${volStr}${extra}`
                                    } else {
                                        return `Volume ${Math.round(audioPanel.sinkVolume * 100)}%` +
                                            (audioPanel.sinkMuted ? " (Muted)" : "") +
                                            (audioPanel.sourceMuted ? "  ·  Mic muted" : "")
                                    }
                                }
                                font.family: Appearance.font.family.main
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Normal
                                color: TuiStyle.dim
                                elide: Text.ElideRight
                            }
                        }

                        // Right Side: Media Controls + Settings Gear
                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 1

                            // Media Controls (only shown when media playing)
                            RowLayout {
                                visible: audioPanel.showMediaControls
                                spacing: 0

                                // Prev
                                Item {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    opacity: audioPanel.activePlayer?.canGoPrevious ? 1 : 0.3

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "skip_previous"
                                        iconSize: 18
                                        color: TuiStyle.fg
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: audioPanel.activePlayer?.canGoPrevious ?? false
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: audioPanel.mediaPrev()
                                    }
                                }

                                // Play/Pause (compact circular button)
                                Rectangle {
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 30
                                    radius: 15
                                    color: headerPlayMouse.containsMouse ? TuiStyle.controlHover : TuiStyle.selection
                                    border.width: 1
                                    border.color: TuiStyle.accent

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: audioPanel.isPlaying ? "pause" : "play_arrow"
                                        iconSize: 17
                                        color: TuiStyle.accent
                                    }
                                    MouseArea {
                                        id: headerPlayMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: audioPanel.mediaToggle()
                                    }
                                }

                                // Next
                                Item {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    opacity: audioPanel.activePlayer?.canGoNext ? 1 : 0.3

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "skip_next"
                                        iconSize: 18
                                        color: TuiStyle.fg
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: audioPanel.activePlayer?.canGoNext ?? false
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: audioPanel.mediaNext()
                                    }
                                }
                            }

                            // Settings Gear (always shown)
                            Item {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: headerSettingsMouse.containsMouse ? TuiStyle.surfaceHover : "transparent"
                                }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "settings"
                                    iconSize: 20
                                    color: headerSettingsMouse.containsMouse ? TuiStyle.fg : TuiStyle.muted
                                }

                                MouseArea {
                                    id: headerSettingsMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.close()
                                        Quickshell.execDetached(["env", "GDK_SCALE=1", "GDK_DPI_SCALE=0.5", "pavucontrol"])
                                    }
                                }
                            }
                        }
                    }

                    // Bottom Divider
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: TuiStyle.line
                        opacity: TuiStyle.dividerOpacity
                    }
                }

                PopupSliderRow {
                    icon: audioPanel.sinkMuted ? NerdIconMap.volumeOff : NerdIconMap.volumeHigh
                    value: audioPanel.sinkVolume
                    muted: audioPanel.sinkMuted
                    onMoved: value => audioPanel.setSinkVolume(value)
                    onIconClicked: { audioPanel.pinOpen(); Audio.toggleMute() }
                }

                PopupSliderRow {
                    icon: audioPanel.sourceMuted ? NerdIconMap.micOff : NerdIconMap.mic
                    value: audioPanel.sourceVolume
                    muted: audioPanel.sourceMuted
                    onMoved: value => audioPanel.setSourceVolume(value)
                    onIconClicked: { audioPanel.pinOpen(); Audio.toggleMicMute() }
                }

                // ── Now playing: compact row (no art, no seek) ───────────
                // Title + status on the left, transport on the right.


                Divider {}

                // ── Output devices (always visible; no expand/collapse) ────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 20
                        Layout.rightMargin: 16
                        Layout.topMargin: 10
                        Layout.bottomMargin: 4
                        text: "Output"
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: TuiStyle.dim
                    }

                    Repeater {
                        model: Audio.typedSinks
                        delegate: MouseArea {
                            id: sinkRow
                            required property var modelData
                            readonly property var node: modelData
                            readonly property bool isActive: {
                                const cur = Audio.sink;
                                if (!cur || !node)
                                    return false;
                                if (cur.name && node.name && cur.name === node.name)
                                    return true;
                                return Audio.nodeObjectId(cur) === Audio.nodeObjectId(node)
                                    && Audio.nodeObjectId(node).length > 0;
                            }

                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            implicitHeight: 40
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                audioPanel.pinOpen();
                                if (node)
                                    Audio.setDefaultSink(node);
                                else if (modelData?.name)
                                    Audio.setDefaultSinkByName(modelData.name);
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: sinkRow.isActive
                                    ? Qt.rgba(TuiStyle.accent.r, TuiStyle.accent.g, TuiStyle.accent.b, 0.12)
                                    : (sinkRow.pressed
                                        ? TuiStyle.selection
                                        : (sinkRow.containsMouse ? TuiStyle.surfaceHover : "transparent"))

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 20
                                    anchors.rightMargin: 16
                                    spacing: 8

                                    MaterialSymbol {
                                        text: sinkRow.isActive ? "check" : "volume_up"
                                        iconSize: 16
                                        color: sinkRow.isActive ? TuiStyle.accent : TuiStyle.muted
                                        Layout.preferredWidth: 20
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: Audio.friendlyDeviceName(sinkRow.node)
                                        color: sinkRow.isActive ? TuiStyle.accent : TuiStyle.fg
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: sinkRow.isActive ? Font.DemiBold : Font.Normal
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 20
                        Layout.rightMargin: 16
                        Layout.preferredHeight: 36
                        verticalAlignment: Text.AlignVCenter
                        visible: Audio.typedSinks.length === 0
                        text: "No output devices"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: TuiStyle.dim
                    }
                }

                // ── Input devices (always visible) ───────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 20
                        Layout.rightMargin: 16
                        Layout.topMargin: 8
                        Layout.bottomMargin: 4
                        text: "Input"
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: TuiStyle.dim
                    }

                    Repeater {
                        model: Audio.typedSources
                        delegate: MouseArea {
                            id: sourceRow
                            required property var modelData
                            readonly property var node: modelData
                            readonly property bool isActive: {
                                const cur = Audio.source;
                                if (!cur || !node)
                                    return false;
                                if (cur.name && node.name && cur.name === node.name)
                                    return true;
                                return Audio.nodeObjectId(cur) === Audio.nodeObjectId(node)
                                    && Audio.nodeObjectId(node).length > 0;
                            }

                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            implicitHeight: 40
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                audioPanel.pinOpen();
                                if (node)
                                    Audio.setDefaultSource(node);
                                else if (modelData?.name)
                                    Audio.setDefaultSourceByName(modelData.name);
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: sourceRow.isActive
                                    ? Qt.rgba(TuiStyle.accent.r, TuiStyle.accent.g, TuiStyle.accent.b, 0.12)
                                    : (sourceRow.pressed
                                        ? TuiStyle.selection
                                        : (sourceRow.containsMouse ? TuiStyle.surfaceHover : "transparent"))

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 20
                                    anchors.rightMargin: 16
                                    spacing: 8

                                    MaterialSymbol {
                                        text: sourceRow.isActive ? "check" : "mic"
                                        iconSize: 16
                                        color: sourceRow.isActive ? TuiStyle.accent : TuiStyle.muted
                                        Layout.preferredWidth: 20
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: Audio.friendlyDeviceName(sourceRow.node)
                                        color: sourceRow.isActive ? TuiStyle.accent : TuiStyle.fg
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: sourceRow.isActive ? Font.DemiBold : Font.Normal
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 20
                        Layout.rightMargin: 16
                        Layout.preferredHeight: 36
                        Layout.bottomMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        visible: Audio.typedSources.length === 0
                        text: "No input devices"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: TuiStyle.dim
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 8
                        visible: Audio.typedSources.length > 0
                    }
                }
            }

            // Prefer WheelHandler over a full-panel MouseArea so device rows
            // never compete with a sibling for pointer events.
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => root.adjustOutputVolumeFromWheel(event, audioPanel)
            }
        }
    }

    Component {
        id: displayContent
        PopupColumn {
            // Same monitor the popup/bar is on — matches keyboard brightness + wheel on icon.
            readonly property var targetScreen: popupWindow.screen
                ?? root.popupScreen
                ?? root.focusedScreen
                ?? Quickshell.screens[0]
            readonly property var brightnessMonitor: Brightness.getMonitorForScreen(targetScreen)
            readonly property real brightnessValue: brightnessMonitor?.brightness ?? 0
            readonly property bool canControlBrightness: {
                if (!targetScreen || !brightnessMonitor)
                    return false;
                const n = targetScreen.name || "";
                const internal = n.startsWith("eDP") || n.startsWith("LVDS") || n.startsWith("DSI") || n.startsWith("DPI");
                return internal || !!brightnessMonitor.isDdc;
            }
            readonly property string monitorLabel: targetScreen?.name ?? "?"

            PopupHeader {
                Layout.fillWidth: true
                icon: NerdIconMap.desktop
                title: "Display"
                subtitle: canControlBrightness
                    ? `Brightness ${Math.round(brightnessValue * 100)}%  ·  ${monitorLabel}` +
                        (Hyprsunset.temperatureActive ? "  ·  Night mode on" : "")
                    : `${monitorLabel}  ·  no brightness control (need DDC/i2c)` +
                        (Hyprsunset.temperatureActive ? "  ·  Night mode on" : "")
                tone: !canControlBrightness
                    ? TuiStyle.warning
                    : (Hyprsunset.temperatureActive ? TuiStyle.warning : TuiStyle.accent)
            }

            // Brightness slider — only this monitor (same rules as omd-brightness-display)
            PopupSliderRow {
                icon: NerdIconMap.brightness6
                value: brightnessValue
                muted: false
                opacity: canControlBrightness ? 1 : 0.4
                onMoved: value => {
                    if (!canControlBrightness || !brightnessMonitor)
                        return;
                    Brightness.lastAdjustedScreenName = targetScreen?.name ?? "";
                    GlobalStates.osdBrightnessScreen = targetScreen?.name ?? "";
                    brightnessMonitor.setBrightness(value);
                }
            }

            PopupToggleRow {
                label: "Night mode"
                checked: Hyprsunset.temperatureActive
                onToggled: checked => Hyprsunset.toggleTemperature(checked)
                showDivider: false
            }

            // Keep this row in the layout so toggling night mode never resizes
            // the popup. Its enabled state is communicated with a subtle fade.
            PopupSliderRow {
                enabled: Hyprsunset.temperatureActive
                opacity: Hyprsunset.temperatureActive ? 1 : 0.35
                icon: NerdIconMap.brightness6
                value: (6500 - (Config.options.light.night.colorTemperature ?? 6000)) / (6500 - 2500)
                muted: false
                onMoved: value => {
                    const temp = Math.round(6500 - value * (6500 - 2500));
                    Config.setNestedValue("light.night.colorTemperature", temp);
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }

            PopupFooterLink {
                Layout.fillWidth: true
                label: "Display settings…"
                onClicked: root.openDialog("display")
            }
        }
    }

    Component {
        id: batteryContent
        ShellCard {
            id: batteryStack
            width: parent?.width ?? implicitWidth
            property bool hibernateAvailable: false
            readonly property var brightnessMonitor: Brightness.getMonitorForScreen(
                Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            )
            readonly property real brightnessValue: brightnessMonitor?.brightness ?? 0
            readonly property int chargeLimit: Config.options.battery.full ?? 100

            function stateLabel() {
                if (!Battery.available) return "desktop";
                if (Battery.isCharging) return "charging";
                if (Battery.isPluggedIn) return "plugged";
                return "battery";
            }

            function headerTitle() {
                return Battery.available ? "BATTERY" : "POWER";
            }

            function headerStatus() {
                if (!Battery.available) return "DESKTOP";
                return `${Math.round(Battery.percentage * 100)}%`;
            }

            function headerTone() {
                if (!Battery.available) return TuiStyle.accent;
                if (Battery.isLowAndNotCharging) return TuiStyle.danger;
                if (Battery.isCharging) return TuiStyle.warning;
                return TuiStyle.success;
            }

            function formatDuration(seconds) {
                const h = Math.floor(seconds / 3600);
                const m = Math.floor((seconds % 3600) / 60);
                if (h > 0)
                    return `${h}h ${m}m`;
                return `${m}m`;
            }

            function showTimeEstimate() {
                const timeValue = Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty;
                const power = Battery.energyRate;
                return Battery.available
                    && !(Battery.chargeState === 4 || timeValue <= 0 || power <= 0.01);
            }

            function timeEstimateLabel() {
                return Battery.isCharging ? "TIME TO FULL" : "TIME LEFT";
            }

            function timeEstimateValue() {
                const seconds = Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty;
                return formatDuration(seconds);
            }

            function timeEstimateColor() {
                if (Battery.isLowAndNotCharging) return TuiStyle.danger;
                if (Battery.isCharging) return TuiStyle.warning;
                return TuiStyle.muted;
            }

            function profileLabel() {
                const profile = PowerProfiles.currentProfile;
                if (profile === "performance") return "performance";
                if (profile === "balanced") return "balanced";
                if (profile === "power-saver") return "power saver";
                return profile;
            }

            function executeAction(action) {
                if (action === "lock") { root.close(); Session.lock(); return; }
                if (action === "sleep") { Session.suspend(); root.close(); return; }
                if (action === "hibernate") { Session.hibernate(); root.close(); return; }
                if (action === "logout") { Session.logout(); root.close(); return; }
                if (action === "reboot") { Session.reboot(); root.close(); return; }
                if (action === "poweroff") { Session.poweroff(); root.close(); return; }
            }

            function requestAction(action, label) {
                if (action === "lock" || action === "sleep" || action === "hibernate") {
                    executeAction(action)
                    return
                }
                GlobalStates.requestSessionConfirm(action, label)
                root.close()
            }

            Component.onCompleted: hibernateCheck.running = true

            Process {
                id: hibernateCheck
                command: ["bash", "-c", "grep -q disk /sys/power/state && echo YES || echo NO"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        batteryStack.hibernateAvailable = text.trim() === "YES"
                    }
                }
            }

            PopupHeader {
                Layout.fillWidth: true
                icon: Battery.available ? NerdIconMap.batteryFull : NerdIconMap.power
                title: Battery.available ? "Power & Battery" : "Power"
                subtitle: batteryStack.headerStatus() + (batteryStack.showTimeEstimate() ? "  ·  " + batteryStack.timeEstimateValue() + " remaining" : "")
                tone: batteryStack.headerTone()
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Battery.available ? 24 : 0
                spacing: 12
                visible: Battery.available

                TuiMeterBar {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 10
                    Layout.alignment: Qt.AlignVCenter
                    value: Battery.percentage * 100
                    accent: Battery.isLowAndNotCharging ? TuiStyle.danger : Battery.isCharging ? TuiStyle.warning : TuiStyle.success
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    text: `${Math.round(Battery.percentage * 100)}%`
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Battery.isLowAndNotCharging ? TuiStyle.danger : TuiStyle.fg
                }
            }

            TuiDetailRow {
                visible: Battery.available
                keyText: "STATE"
                valueText: batteryStack.stateLabel()
                valueColor: batteryStack.headerTone()
                keyWidth: 96
            }

            TuiDetailRow {
                visible: batteryStack.showTimeEstimate()
                keyText: batteryStack.timeEstimateLabel()
                valueText: batteryStack.timeEstimateValue()
                valueColor: batteryStack.timeEstimateColor()
                keyWidth: 96
            }

            TuiDetailRow {
                visible: Battery.available && Battery.chargeState !== 4 && Battery.energyRate > 0.01
                keyText: "POWER DRAW"
                valueText: `${Battery.energyRate.toFixed(1)}W`
                valueColor: Battery.isCharging ? TuiStyle.warning : TuiStyle.info
                keyWidth: 96
            }

            SectionLabel {
                visible: PowerProfiles.available
                text: "POWER PROFILE"
                topInset: Battery.available ? 4 : 0
            }

            // ── Power Profile — vertical list, GNOME style ───────────────
            Item {
                Layout.fillWidth: true
                visible: PowerProfiles.available
                implicitHeight: profileList.implicitHeight

                ColumnLayout {
                    id: profileList
                    anchors { left: parent.left; right: parent.right }
                    spacing: 0

                    Repeater {
                        model: [
                            { id: "power-saver",   title: "Power Saver",   desc: "Reduced power usage and performance.", icon: NerdIconMap.eco },
                            { id: "balanced",      title: "Balanced",      desc: "Standard performance and battery usage.", icon: NerdIconMap.bolt },
                            { id: "performance",   title: "High Performance", desc: "High performance and power usage.", icon: NerdIconMap.speed }
                        ]

                        delegate: Item {
                            Layout.fillWidth: true
                            implicitHeight: profileRow.implicitHeight + 20

                            required property var modelData
                            readonly property bool isActive: PowerProfiles.currentProfile === modelData.id

                            RowLayout {
                                id: profileRow
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 20
                                    rightMargin: 20
                                }
                                spacing: 12

                                NerdIcon {
                                    iconSize: 18
                                    text: modelData.icon
                                    color: isActive ? TuiStyle.accent : TuiStyle.dim
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.title
                                        font.family: Appearance.font.family.main
                                        font.pixelSize: Appearance.font.pixelSize.normal + 1
                                        font.weight: Font.Medium
                                        color: TuiStyle.fg
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.desc
                                        font.family: Appearance.font.family.main
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: TuiStyle.dim
                                        elide: Text.ElideRight
                                    }
                                }

                                // Checkmark for active profile
                                NerdIcon {
                                    iconSize: 16
                                    text: NerdIconMap.check
                                    color: TuiStyle.accent
                                    visible: isActive
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: PowerProfiles.setProfile(modelData.id)
                            }
                        }
                    }
                }
            }

            SectionLabel { text: "SESSION" }

            TileTrack {
                PanelTile {
                    icon: NerdIconMap.lock
                    label: "LOCK"
                    tone: TuiStyle.accent
                    onClicked: batteryStack.requestAction("lock", "Lock")
                }
                PanelTile {
                    icon: NerdIconMap.darkMode
                    label: "SLEEP"
                    tone: TuiStyle.info
                    onClicked: batteryStack.requestAction("sleep", "Sleep")
                }
                PanelTile {
                    icon: NerdIconMap.download
                    label: "HIBERNATE"
                    tone: TuiStyle.purple
                    visible: batteryStack.hibernateAvailable
                    onClicked: batteryStack.requestAction("hibernate", "Hibernate")
                }
                PanelTile {
                    icon: NerdIconMap.logout
                    label: "LOGOUT"
                    tone: TuiStyle.warning
                    showDivider: false
                    onClicked: batteryStack.requestAction("logout", "Logout")
                }
            }

            SectionLabel { text: "POWER" }

            TileTrack {
                PanelTile {
                    icon: NerdIconMap.restart
                    label: "REBOOT"
                    tone: TuiStyle.info
                    onClicked: batteryStack.requestAction("reboot", "Reboot")
                }
                PanelTile {
                    icon: NerdIconMap.powerSettingsNew
                    label: "SHUTDOWN"
                    tone: TuiStyle.danger
                    onClicked: batteryStack.requestAction("poweroff", "Shutdown")
                }
                PanelTile {
                    icon: NerdIconMap.refresh
                    label: "RELOAD"
                    tone: TuiStyle.accent
                    showDivider: false
                    onClicked: {
                        Quickshell.execDetached(["bash", `${FileUtils.trimFileProtocol(Directories.config)}/omd/scripts/reload-quickshell`]);
                        root.close();
                    }
                }
            }
        }
    }

    // Shared tile chrome — one subtle outer track, inner cells separated by hairline dividers.
    readonly property color tileTrackBorder: Qt.rgba(TuiStyle.line.r, TuiStyle.line.g, TuiStyle.line.b, 0.22)

    component TileTrack: Rectangle {
        id: track
        default property alias cells: cellRow.data

        Layout.fillWidth: true
        Layout.preferredHeight: 50
        implicitHeight: 50
        radius: SettingsTokens.radius
        color: SettingsTokens.button
        border.width: 1
        border.color: SettingsTokens.buttonBorder
        clip: true

        RowLayout {
            id: cellRow
            anchors.fill: parent
            spacing: 0
        }
    }

    component PanelTile: Item {
        id: tile
        property string icon: ""
        property string label: ""
        property color tone: TuiStyle.accent
        property bool active: false
        property bool showDivider: true
        signal clicked()

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: 0

        readonly property bool engaged: tile.active || tileMouse.pressed || tileMouse.containsMouse

        Rectangle {
            id: tileBg
            anchors.fill: parent
            radius: SettingsTokens.radius
            color: tileMouse.pressed ? SettingsTokens.buttonHover
                : tile.active ? SettingsTokens.buttonActive
                : tileMouse.containsMouse ? SettingsTokens.buttonHover
                : "transparent"

            Behavior on color {
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: parent.height * 0.55
            radius: 0.5
            color: SettingsTokens.line
            opacity: 0.18
            visible: tile.showDivider
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.max(0, tile.width - 6)
            spacing: tile.active ? 2 : 3

            NerdIcon {
                Layout.alignment: Qt.AlignHCenter
                iconSize: tile.active ? 17 : 19
                text: tile.icon
                color: tile.active ? SettingsTokens.accent
                    : tile.engaged ? tile.tone
                    : SettingsTokens.dim
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: tile.label
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: tile.active ? Font.Bold : Font.DemiBold
                color: tile.active ? SettingsTokens.fg
                    : tile.engaged ? SettingsTokens.fg
                    : SettingsTokens.dim
            }
        }
    }

    Component {
        id: notificationsContent
        PopupColumn {
            PopupHeader {
                Layout.fillWidth: true
                icon: Notifications.silent ? NerdIconMap.notificationsOff : NerdIconMap.notifications
                title: "Notifications"
                subtitle: Notifications.silent
                    ? "Do not disturb"
                    : (Notifications.list.length === 0
                        ? "All clear"
                        : `${Notifications.list.length} notification${Notifications.list.length === 1 ? "" : "s"}`)
                tone: Notifications.silent ? TuiStyle.warning : TuiStyle.success

                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 12

                    // Broom button to clear notifications
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        text: "delete_sweep"
                        iconSize: 20
                        color: clearMouse.containsMouse ? TuiStyle.danger : TuiStyle.dim
                        visible: Notifications.list.length > 0

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifications.discardAllNotifications()
                        }
                    }

                    // DND Toggle Switch - unified size
                    Rectangle {
                        id: dndToggle
                        Layout.alignment: Qt.AlignVCenter
                        width: 46
                        height: 26
                        radius: height / 2
                        color: !Notifications.silent ? TuiStyle.accent : TuiStyle.controlMuted
                        border.width: TuiStyle.borderWidth
                        border.color: !Notifications.silent ? TuiStyle.shellBorder : TuiStyle.line

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            anchors.verticalCenter: parent.verticalCenter
                            x: !Notifications.silent ? parent.width - width - 3 : 3
                            color: !Notifications.silent ? TuiStyle.bg : TuiStyle.fg
                            Behavior on x { NumberAnimation { duration: 110 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifications.toggleSilent()
                        }
                    }
                }
            }

            TuiNotificationList {
                Layout.fillWidth: true
                Layout.topMargin: visible ? 12 : 0
                visible: !Notifications.silent
                Layout.bottomMargin: 16
                showHeader: false
                showFooter: false
                showFooterDnd: false
                compactRows: true
                markReadOnVisible: true
                maxListHeight: Math.round((popupWindow.screen?.height ?? 900) * 0.72)
            }
        }
    }

    Component {
        id: voiceContent
        PopupColumn {
            id: voicePanel

            function stateLabel() {
                if (VoiceInput.state === "setup") return "Not Installed";
                if (VoiceInput.state === "idle") return "Ready";
                if (VoiceInput.state === "recording") return "Recording";
                if (VoiceInput.state === "transcribing") return "Transcribing";
                if (VoiceInput.state === "success") return "Transcription Success";
                if (VoiceInput.state === "error") return "Error";
                return VoiceInput.state;
            }
            function tone() {
                if (VoiceInput.state === "idle" || VoiceInput.state === "success") return TuiStyle.success;
                if (VoiceInput.state === "recording" || VoiceInput.state === "error") return TuiStyle.danger;
                if (VoiceInput.state === "transcribing" || VoiceInput.state === "setup") return TuiStyle.warning;
                return TuiStyle.muted;
            }

            PopupHeader {
                Layout.fillWidth: true
                icon: NerdIconMap.mic
                title: "Voice Input"
                subtitle: voicePanel.stateLabel()
                tone: voicePanel.tone()
            }

            // Model status card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: modelCol.implicitHeight + 16
                color: TuiStyle.panel
                radius: TuiStyle.radius
                clip: true

                ColumnLayout {
                    id: modelCol
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    PopupInfoRow {
                        label: "Model"
                        value: VoiceInput.modelSizeMB > 0 ? `SenseVoice Small (${VoiceInput.modelSizeMB} MB)` : "Missing"
                        valueColor: VoiceInput.modelSizeMB > 0 ? TuiStyle.success : TuiStyle.danger
                        showDivider: true
                    }

                    PopupInfoRow {
                        label: "Daemon Status"
                        value: VoiceInput.daemonRunning ? "Active (RAM Loaded)" : "Standby"
                        valueColor: VoiceInput.daemonRunning ? TuiStyle.success : TuiStyle.dim
                        showDivider: true
                    }

                    PopupInfoRow {
                        label: "Virtual Env"
                        value: VoiceInput.state === "setup" ? "Missing" : "Ready"
                        valueColor: VoiceInput.state === "setup" ? TuiStyle.danger : TuiStyle.success
                        showDivider: false
                    }
                }
            }

            // Debug test section
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: debugCol.implicitHeight + 16
                color: TuiStyle.panel
                radius: TuiStyle.radius
                clip: true
                visible: VoiceInput.state !== "setup"

                ColumnLayout {
                    id: debugCol
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // Circle button for record toggle
                        Rectangle {
                            id: debugRecBtn
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            radius: 24
                            color: VoiceInput.state === "recording" ? TuiStyle.danger : recMouse.containsMouse ? TuiStyle.surfaceHover : TuiStyle.surfaceRaised
                            border.width: 1
                            border.color: VoiceInput.state === "recording" ? TuiStyle.danger : TuiStyle.line

                            NerdIcon {
                                anchors.centerIn: parent
                                iconSize: 20
                                text: VoiceInput.state === "recording" ? NerdIconMap.stop : NerdIconMap.mic
                                color: VoiceInput.state === "recording" ? TuiStyle.fg : TuiStyle.fg
                            }

                            MouseArea {
                                id: recMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: VoiceInput.state === "idle" || VoiceInput.state === "recording"
                                onClicked: {
                                    if (VoiceInput.state === "recording") {
                                        VoiceInput.stopRecording();
                                    } else {
                                        VoiceInput.testRecording();
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                text: {
                                    if (VoiceInput.state === "recording") return `Recording ${VoiceInput.recordingDuration.toFixed(1)}s`
                                    if (VoiceInput.state === "transcribing") return "Transcribing…"
                                    if (VoiceInput.state === "success") return "Transcription ready"
                                    if (VoiceInput.state === "error") return "Error"
                                    return "Tap mic to test 3s"
                                }
                                font.family: Appearance.font.family.main
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: voicePanel.tone()
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: VoiceInput.lastError || VoiceInput.lastTranscription || "—"
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                font.family: Appearance.font.family.main
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: VoiceInput.lastError ? TuiStyle.danger : TuiStyle.fg
                            }
                        }
                    }

                    ActionRow {
                        PopupActionButton {
                            label: "COPY TEXT"
                            enabledState: VoiceInput.lastTranscription.length > 0
                            onClicked: {
                                Quickshell.execDetached(["bash", "-c",
                                    `printf '%s' '${StringUtils.shellSingleQuoteEscape(VoiceInput.lastTranscription)}' | wl-copy`]);
                                VoiceInput.notify("Copied", VoiceInput.lastTranscription, "edit-copy");
                            }
                        }
                        PopupActionButton {
                            label: "PASTE"
                            enabledState: VoiceInput.lastTranscription.length > 0
                            onClicked: {
                                Quickshell.execDetached(["bash", "-c",
                                    `printf '%s' '${StringUtils.shellSingleQuoteEscape(VoiceInput.lastTranscription)}' | wl-copy && ` +
                                    `'${VoiceInput.shareDir}/omd-paste-at-cursor' auto`]);
                            }
                        }
                    }
                }
            }

            // History section
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(historyList.implicitHeight + 16, 160)
                color: TuiStyle.panel
                radius: TuiStyle.radius
                clip: true
                visible: VoiceInput.history.length > 0

                ColumnLayout {
                    id: historyList
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    StyledText {
                        text: `History (${VoiceInput.history.length})`
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Bold
                        color: TuiStyle.dim
                    }

                    ColumnLayout {
                        spacing: 0
                        Repeater {
                            model: VoiceInput.history.slice(0, 5)
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 24
                                color: histMouse.containsMouse ? TuiStyle.panelAlt : "transparent"

                                MouseArea {
                                    id: histMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Quickshell.execDetached(["bash", "-c",
                                            `printf '%s' '${StringUtils.shellSingleQuoteEscape(modelData.text)}' | wl-copy`]);
                                        root.close();
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: 4
                                    spacing: 8

                                    StyledText {
                                        text: modelData.time
                                        font.family: Appearance.font.family.monospace
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: TuiStyle.dim
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.text
                                        elide: Text.ElideRight
                                        font.family: Appearance.font.family.main
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: histMouse.containsMouse ? TuiStyle.fg : TuiStyle.muted
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ActionRow {
                PopupActionButton {
                    label: VoiceInput.state === "setup" ? "Setup" : "Test"
                    onClicked: {
                        if (VoiceInput.state === "setup") {
                            VoiceInput.setup();
                        } else {
                            VoiceInput.testRecording();
                        }
                        root.close();
                    }
                }
                PopupActionButton {
                    label: "Check State"
                    onClicked: {
                        VoiceInput.checkState();
                        VoiceInput.refreshModelInfo();
                        VoiceInput.refreshDaemonStatus();
                    }
                }
                PopupActionButton {
                    label: "Clear History"
                    visible: VoiceInput.history.length > 0
                    onClicked: VoiceInput.clearHistory()
                }
            }

            PopupFooterLink {
                Layout.fillWidth: true
                label: "Voice Settings…"
                onClicked: {
                    root.close();
                    Quickshell.execDetached([`${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-settings`, "open", "voice"]);
                }
            }
        }
    }
}
