pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.schedulePopup.notifications
import qs.modules.settings
import qs.modules.settings.widgets
import qs.services
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

    function close() {
        GlobalStates.barPopupEphemeral = false;
        GlobalStates.barPopupType = "";
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
        screen: root.focusedScreen
        visible: root.open && root.focusedScreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:barstatus"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

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
                popupWindow.screen = root.focusedScreen;
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
                        if (root.activeType === "keyboard") return keyboardContent;
                        if (root.activeType === "session") return sessionContent;
                        if (root.activeType === "clipboard") return clipboardContent;
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
        id: clipboardContent
        PopupColumn {
            id: clipboardPanel
            property list<string> entries: Cliphist.entries

            PopupHeader {
                Layout.fillWidth: true
                icon: NerdIconMap.contentPaste
                title: "Clipboard"
                subtitle: `${clipboardPanel.entries.length} item${clipboardPanel.entries.length === 1 ? "" : "s"} in history`
            }

            // Clipboard entries list
            Item {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Layout.preferredHeight: Math.min(clipboardPanel.entries.length * 44 + 8, 320)
                visible: clipboardPanel.entries.length > 0

                ListView {
                    id: clipboardListView
                    anchors.fill: parent
                    spacing: 2
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: clipboardPanel.entries.slice(0, 10)
                    ScrollBar.vertical: StyledScrollBar {}

                    delegate: Rectangle {
                        required property var modelData
                        width: clipboardListView.width
                        height: 44
                        radius: TuiStyle.radius
                        color: itemMouse.containsMouse ? TuiStyle.surfaceHover : "transparent"

                        Behavior on color { ColorAnimation { duration: 80 } }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Cliphist.copy(modelData);
                                root.close();
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 12

                            NerdIcon {
                                Layout.alignment: Qt.AlignVCenter
                                iconSize: 16
                                text: NerdIconMap.contentPaste
                                color: itemMouse.containsMouse ? TuiStyle.accent : TuiStyle.dim
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                verticalAlignment: Text.AlignVCenter
                                text: modelData.replace(/^\s*\S+\s+/, "").slice(0, 60)
                                elide: Text.ElideRight
                                font.family: Appearance.font.family.main
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: itemMouse.containsMouse ? TuiStyle.fg : TuiStyle.dim
                            }

                            NerdIcon {
                                Layout.alignment: Qt.AlignVCenter
                                iconSize: 12
                                text: NerdIconMap.chevronRight
                                color: TuiStyle.dim
                                opacity: itemMouse.containsMouse ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 80 } }
                            }
                        }
                    }
                }
            }

            // Top divider for footer
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 8
                height: 1
                color: TuiStyle.line
                opacity: TuiStyle.dividerOpacity
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                spacing: 10

                StyledText {
                    text: "Clipboard manager…"
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: linkMouse.containsMouse ? TuiStyle.fg : TuiStyle.dim
                    Behavior on color { ColorAnimation { duration: 100 } }

                    MouseArea {
                        id: linkMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.close();
                            Quickshell.execDetached([`${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-clipboard`, "toggle"]);
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    visible: clipboardPanel.entries.length > 0
                    implicitWidth: Math.max(88, clearClipLabel.implicitWidth + 24)
                    implicitHeight: 32
                    radius: TuiStyle.radius
                    color: clearClipMouse.pressed ? TuiStyle.controlHover
                        : clearClipMouse.containsMouse ? TuiStyle.controlHover
                        : TuiStyle.control
                    border.width: 0

                    StyledText {
                        id: clearClipLabel
                        anchors.centerIn: parent
                        text: "Clear All"
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: TuiStyle.fg
                    }

                    MouseArea {
                        id: clearClipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { Cliphist.wipe(); root.close(); }
                    }
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

            function connStatus() {
                if (Network.ethernet) return "Connected";
                if (!Network.wifiEnabled || Network.wifiStatus === "disabled") return "Disabled";
                const s = Network.wifiStatus || "disconnected";
                return s.charAt(0).toUpperCase() + s.slice(1);
            }
            function connTone() {
                const s = wifiPanel.connStatus();
                if (s === "Connected") return TuiStyle.success;
                if (s === "Disabled") return TuiStyle.danger;
                if (s === "Connecting" || s === "Limited") return TuiStyle.warning;
                return TuiStyle.muted;
            }
            function connIcon() {
                return Network.ethernet ? NerdIconMap.ethernet : NerdIconMap.wifi
            }
            function connName() {
                if (Network.ethernet) return Network.networkName || "Wired Connection";
                return Network.active?.ssid || Network.networkName || "Not connected";
            }
            function connDetail() {
                if (Network.ethernet) return "";
                if (!Network.ethernet && Network.wifiStatus === "connected")
                    return `Signal: ${Network.active?.strength ?? Network.networkStrength}%  ·  ${Network.friendlyWifiNetworks.length} network${Network.friendlyWifiNetworks.length === 1 ? "" : "s"} visible`;
                return `${Network.friendlyWifiNetworks.length} network${Network.friendlyWifiNetworks.length === 1 ? "" : "s"} visible`;
            }

            PopupDeviceRow {
                Layout.fillWidth: true
                icon: wifiPanel.connIcon()
                name: wifiPanel.connName()
                detail: wifiPanel.connDetail()
                status: wifiPanel.connStatus()
                statusColor: wifiPanel.connTone()
            }

            PopupToggleRow {
                label: "Wi-Fi"
                checked: Network.wifiEnabled
                onToggled: checked => Network.enableWifi(checked)
            }

            PopupToggleRow {
                label: "Bluetooth"
                checked: BluetoothStatus.enabled
                enabled: BluetoothStatus.available
                onToggled: checked => { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = checked }
                showDivider: false
            }

            PopupFooterLink {
                Layout.fillWidth: true
                label: "Network settings…"
                onClicked: root.openDialog("wifi")
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
                onToggled: checked => { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = checked }
                showDivider: false
            }

            PopupFooterLink {
                Layout.fillWidth: true
                label: "Bluetooth settings…"
                onClicked: root.openDialog("bluetooth")
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
            readonly property bool hasActivePlayer: activePlayer !== null && activePlayer !== undefined
            readonly property string trackTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || "--"
            readonly property string trackArtist: activePlayer?.trackArtist ?? ""
            readonly property bool isPlaying: activePlayer?.isPlaying ?? false

            function pinOpen() { GlobalStates.barPopupEphemeral = false; }
            function setSinkVolume(value) { audioPanel.pinOpen(); Audio.setSinkVolume(value); }
            function setSourceVolume(value) { audioPanel.pinOpen(); Audio.setSourceVolume(value); }

            ColumnLayout {
                id: audioColumn
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0

                PopupHeader {
                    Layout.fillWidth: true
                    icon: audioPanel.sinkMuted ? NerdIconMap.volumeOff : NerdIconMap.volumeHigh
                    title: "Volume"
                    subtitle: `Volume ${Math.round(audioPanel.sinkVolume * 100)}%` +
                        (audioPanel.sinkMuted ? " (Muted)" : "") +
                        (audioPanel.sourceMuted ? "  ·  Mic muted" : "")
                    tone: audioPanel.sinkMuted ? TuiStyle.warning : TuiStyle.accent
                }

                // ── Sliders ───────────────────────────────────────────────
                PopupSliderRow {
                    icon: audioPanel.sinkMuted ? NerdIconMap.volumeOff : NerdIconMap.volumeHigh
                    value: audioPanel.sinkVolume
                    muted: audioPanel.sinkMuted
                    onMoved: value => audioPanel.setSinkVolume(value)
                    onIconClicked: Audio.toggleMute()
                }

                PopupSliderRow {
                    icon: audioPanel.sourceMuted ? NerdIconMap.micOff : NerdIconMap.mic
                    value: audioPanel.sourceVolume
                    muted: audioPanel.sourceMuted
                    onMoved: value => audioPanel.setSourceVolume(value)
                    onIconClicked: Audio.toggleMicMute()
                }

                Divider {}

                // ── Output device info ────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    implicitHeight: outputColumn.implicitHeight + 16
                    visible: true

                    ColumnLayout {
                        id: outputColumn
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: 20
                            rightMargin: 20
                        }
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: "Output"
                            font.family: Appearance.font.family.main
                            font.pixelSize: Appearance.font.pixelSize.normal + 1
                            font.weight: Font.Medium
                            color: TuiStyle.fg
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: audioPanel.sink ? Audio.friendlyDeviceName(audioPanel.sink) : "--"
                            font.family: Appearance.font.family.main
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: TuiStyle.dim
                            elide: Text.ElideRight
                        }
                    }
                }

                // ── Input device info ─────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    implicitHeight: inputColumn.implicitHeight + 16
                    visible: true

                    ColumnLayout {
                        id: inputColumn
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: 20
                            rightMargin: 20
                        }
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: "Input"
                            font.family: Appearance.font.family.main
                            font.pixelSize: Appearance.font.pixelSize.normal + 1
                            font.weight: Font.Medium
                            color: TuiStyle.fg
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: audioPanel.source ? Audio.friendlyDeviceName(audioPanel.source) : "--"
                            font.family: Appearance.font.family.main
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: TuiStyle.dim
                            elide: Text.ElideRight
                        }
                    }
                }

                PopupFooterLink {
                    Layout.fillWidth: true
                    label: "Sound Settings…"
                    onClicked: { root.close(); Quickshell.execDetached([`${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-settings`, "open", "sound"]); }
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: false
                z: -1
                onWheel: wheel => root.adjustOutputVolumeFromWheel(wheel, audioPanel)
            }
        }
    }

    Component {
        id: displayContent
        PopupColumn {
            readonly property var brightnessMonitor: Brightness.getMonitorForScreen(Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0])
            readonly property real brightnessValue: brightnessMonitor?.brightness ?? 0

            PopupHeader {
                Layout.fillWidth: true
                icon: NerdIconMap.desktop
                title: "Display"
                subtitle: `Brightness ${Math.round(brightnessValue * 100)}%` +
                    (Hyprsunset.temperatureActive ? "  ·  Night mode on" : "")
                tone: Hyprsunset.temperatureActive ? TuiStyle.warning : TuiStyle.accent
            }

            // Brightness slider
            PopupSliderRow {
                icon: NerdIconMap.brightness6
                value: brightnessValue
                muted: false
                onMoved: value => {
                    brightnessMonitor.setBrightness(value);
                }
            }

            PopupToggleRow {
                label: "Night mode"
                checked: Hyprsunset.temperatureActive
                onToggled: checked => Hyprsunset.toggleTemperature(checked)
                showDivider: false
            }

            // Night mode intensity slider (only visible when night mode is on)
            PopupSliderRow {
                visible: Hyprsunset.temperatureActive
                icon: NerdIconMap.brightness6
                value: (6500 - (Config.options.light.night.colorTemperature ?? 6000)) / (6500 - 2500)
                muted: false
                onMoved: value => {
                    const temp = Math.round(6500 - value * (6500 - 2500));
                    Config.setNestedValue("light.night.colorTemperature", temp);
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
                icon: "\uDB81\uDC17"  // mdi-bell U+F0417 (notification icon)
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
                        color: Notifications.silent ? TuiStyle.accent : TuiStyle.controlMuted
                        border.width: TuiStyle.borderWidth
                        border.color: Notifications.silent ? TuiStyle.shellBorder : TuiStyle.line

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            anchors.verticalCenter: parent.verticalCenter
                            x: Notifications.silent ? parent.width - width - 3 : 3
                            color: Notifications.silent ? TuiStyle.bg : TuiStyle.fg
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
                Layout.topMargin: 12
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
