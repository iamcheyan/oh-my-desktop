pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.schedulePopup
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland

Scope {
    id: root

    readonly property string activeType: GlobalStates.barPopupType || ""
    readonly property bool open: activeType.length > 0 && !GlobalStates.screenLocked
    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        ?? Quickshell.screens[0]
        ?? null

    function close() {
        GlobalStates.barPopupType = "";
    }

    function openDialog(dialogType) {
        root.close();
        GlobalStates.barDialogType = dialogType;
        GlobalStates.barDialogOpen = true;
    }

    IpcHandler {
        target: "schedule"

        function toggle(): void {
            GlobalStates.barPopupType = GlobalStates.barPopupType === "schedule" ? "" : "schedule";
        }

        function close(): void {
            if (GlobalStates.barPopupType === "schedule")
                GlobalStates.barPopupType = "";
        }

        function open(): void {
            GlobalStates.barPopupType = "schedule";
        }
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
            GlobalStates.barPopupType = type === "notifications" ? "schedule" : type;
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
            if (root.activeType === "schedule")
                return Math.min(720, Math.max(660, (screen?.width ?? 1920) - 32));
            if (root.activeType === "battery")
                return Math.min(460, Math.max(400, (screen?.width ?? 1920) - 32));
            return 360;
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

        Timer {
            id: dismissGuard
            interval: 150
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
                root.close();
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
                contentPadding: panel.multiShell ? 0 : 14
                color: panel.multiShell ? "transparent" : TuiStyle.bg
                border.width: panel.multiShell ? 0 : TuiStyle.borderWidth
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
                        if (root.activeType === "schedule") return scheduleContent;
                        if (root.activeType === "voice") return voiceContent;
                        return emptyContent;
                    }
                }
            }
        }
    }

    component Header: Rectangle {
        id: header
        property string title: ""
        property string status: ""
        property color tone: TuiStyle.accent

        Layout.fillWidth: true
        Layout.preferredHeight: 44
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            spacing: 10

            StyledText {
                text: header.title
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: TuiStyle.dim
            }

            Item { Layout.fillWidth: true }

            StyledText {
                text: header.status
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
                color: header.status.length > 0 ? header.tone : TuiStyle.fg
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: TuiStyle.line
            opacity: TuiStyle.dividerOpacity
        }
    }

    component PopupColumn: ColumnLayout {
        spacing: 10
        width: parent?.width ?? implicitWidth
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
            border.width: TuiStyle.borderWidth
            border.color: TuiStyle.shellBorder
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
                spacing: 10
            }
        }
    }

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

    component ActionRow: RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Item { Layout.fillWidth: true }
    }

    Component {
        id: emptyContent
        Item { implicitHeight: 1 }
    }

    Component {
        id: wifiContent
        PopupColumn {
            id: wifiPanel
            function stateLabel() {
                if (Network.ethernet) return "wired";
                if (!Network.wifiEnabled || Network.wifiStatus === "disabled") return "disabled";
                return Network.wifiStatus || "disconnected";
            }
            function tone() {
                if (stateLabel() === "connected" || stateLabel() === "wired") return TuiStyle.success;
                if (stateLabel() === "disabled") return TuiStyle.danger;
                if (stateLabel() === "connecting" || stateLabel() === "limited") return TuiStyle.warning;
                return TuiStyle.muted;
            }

            Header { title: Network.ethernet ? "ETHERNET" : "WI-FI"; status: wifiPanel.stateLabel().toUpperCase(); tone: wifiPanel.tone() }
            TuiDetailRow { keyText: "SSID"; valueText: Network.ethernet ? (Network.networkName || "--") : (Network.active?.ssid || Network.networkName || "--") }
            TuiDetailRow { keyText: "SIGNAL"; valueText: !Network.ethernet && stateLabel() === "connected" ? `${Network.active?.strength ?? Network.networkStrength}%` : "--"; valueColor: TuiStyle.info }
            TuiDetailRow { keyText: "NETWORKS"; valueText: `${Network.friendlyWifiNetworks.length}`; valueColor: TuiStyle.muted }
            TuiDetailRow { keyText: "SCANNING"; valueText: Network.wifiScanning ? "yes" : "no"; valueColor: Network.wifiScanning ? TuiStyle.warning : TuiStyle.muted }
            ActionRow {
                TuiActionButton { label: "MANAGE"; onClicked: root.openDialog("wifi") }
            }
        }
    }

    Component {
        id: bluetoothContent
        PopupColumn {
            id: bluetoothPanel
            function stateLabel() {
                if (!BluetoothStatus.available) return "unavailable";
                if (!BluetoothStatus.enabled) return "disabled";
                if (BluetoothStatus.connected) return "connected";
                return "on";
            }
            function tone() {
                if (stateLabel() === "connected") return TuiStyle.success;
                if (stateLabel() === "disabled") return TuiStyle.danger;
                return TuiStyle.muted;
            }

            Header { title: "BLUETOOTH"; status: bluetoothPanel.stateLabel().toUpperCase(); tone: bluetoothPanel.tone() }
            TuiDetailRow { keyText: "ADAPTER"; valueText: BluetoothStatus.available ? "present" : "missing"; valueColor: BluetoothStatus.available ? TuiStyle.success : TuiStyle.danger }
            TuiDetailRow { keyText: "ENABLED"; valueText: BluetoothStatus.enabled ? "yes" : "no"; valueColor: BluetoothStatus.enabled ? TuiStyle.success : TuiStyle.danger }
            TuiDetailRow { keyText: "DEVICES"; valueText: `${BluetoothStatus.friendlyDeviceList?.length ?? 0} total`; valueColor: TuiStyle.muted }
            TuiDetailRow { keyText: "CONNECTED"; valueText: `${BluetoothStatus.activeDeviceCount}`; valueColor: BluetoothStatus.connected ? TuiStyle.success : TuiStyle.muted }
            ActionRow {
                TuiActionButton { label: "MANAGE"; onClicked: root.openDialog("bluetooth") }
            }
        }
    }

    Component {
        id: audioContent
        PopupColumn {
            readonly property PwNode sink: Pipewire.defaultAudioSink
            readonly property PwNode source: Pipewire.defaultAudioSource
            readonly property real sinkVolume: sink?.audio.volume ?? 0
            readonly property bool sinkMuted: sink?.audio.muted ?? false
            readonly property bool sourceMuted: source?.audio.muted ?? false

            Header { title: "AUDIO"; status: sinkMuted ? "MUTED" : "ACTIVE"; tone: sinkMuted ? TuiStyle.danger : TuiStyle.success }
            TuiMeterBar { Layout.fillWidth: true; Layout.preferredHeight: 10; value: sinkMuted ? 0 : sinkVolume * 100; accent: sinkMuted ? TuiStyle.danger : TuiStyle.info }
            TuiDetailRow { keyText: "OUTPUT"; valueText: sink ? Audio.friendlyDeviceName(sink) : "--"; valueColor: TuiStyle.info }
            TuiDetailRow { keyText: "O LEVEL"; valueText: `${Math.round(sinkVolume * 100)}%`; valueColor: sinkMuted ? TuiStyle.danger : TuiStyle.fg }
            TuiDetailRow { keyText: "INPUT"; valueText: source ? Audio.friendlyDeviceName(source) : "--"; valueColor: TuiStyle.muted }
            TuiDetailRow { keyText: "I STATUS"; valueText: sourceMuted ? "muted" : "active"; valueColor: sourceMuted ? TuiStyle.danger : TuiStyle.success }
            ActionRow {
                TuiActionButton { label: "AUDIOCTL"; onClicked: root.openDialog("audio") }
            }
        }
    }

    Component {
        id: displayContent
        PopupColumn {
            readonly property var brightnessMonitor: Brightness.getMonitorForScreen(Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0])
            readonly property real brightnessValue: brightnessMonitor?.brightness ?? 0

            Header { title: "DISPLAY"; status: Hyprsunset.temperatureActive ? "NIGHT" : "NORMAL"; tone: Hyprsunset.temperatureActive ? TuiStyle.warning : TuiStyle.muted }
            TuiMeterBar { Layout.fillWidth: true; Layout.preferredHeight: 10; value: brightnessValue * 100; accent: TuiStyle.warning }
            TuiDetailRow { keyText: "BRIGHTNESS"; valueText: `${Math.round(brightnessValue * 100)}%`; valueColor: TuiStyle.warning }
            TuiDetailRow { keyText: "NIGHT"; valueText: Hyprsunset.temperatureActive ? "on" : "off"; valueColor: Hyprsunset.temperatureActive ? TuiStyle.warning : TuiStyle.muted }
            TuiDetailRow { keyText: "TEMP"; valueText: Hyprsunset.temperatureActive ? `${Hyprsunset.colorTemperature}K` : "--"; valueColor: TuiStyle.muted }
            TuiDetailRow { keyText: "SCREENS"; valueText: `${Quickshell.screens.length}`; valueColor: TuiStyle.success }
            ActionRow {
                TuiActionButton { label: "SETTINGS"; onClicked: root.openDialog("nightlight") }
            }
        }
    }

    Component {
        id: batteryContent
        ShellCard {
            id: batteryStack
            width: parent?.width ?? implicitWidth
            property bool hibernateAvailable: false

            function stateLabel() {
                if (!Battery.available) return "desktop";
                if (Battery.isCharging) return "charging";
                if (Battery.isPluggedIn) return "plugged";
                return "battery";
            }

            function headerTitle() {
                return Battery.available ? "BATTERY" : "POWER";
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

            Header {
                    title: batteryStack.headerTitle()
                    status: batteryStack.stateLabel().toUpperCase()
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
                    topInset: Battery.available ? 2 : 0
                }

                TileTrack {
                    Layout.preferredHeight: 40
                    visible: PowerProfiles.available

                    PanelTile {
                        active: PowerProfiles.currentProfile === "power-saver"
                        icon: NerdIconMap.eco
                        label: "SAVER"
                        onClicked: PowerProfiles.setProfile("power-saver")
                    }
                    PanelTile {
                        active: PowerProfiles.currentProfile === "balanced"
                        icon: NerdIconMap.balance
                        label: "BALANCED"
                        onClicked: PowerProfiles.setProfile("balanced")
                    }
                    PanelTile {
                        active: PowerProfiles.currentProfile === "performance"
                        icon: NerdIconMap.speed
                        label: "PERFORMANCE"
                        showDivider: false
                        onClicked: PowerProfiles.setProfile("performance")
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
        radius: TuiStyle.miniRadius + 4
        color: TuiStyle.controlMuted
        border.width: 1
        border.color: tileTrackBorder
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
            color: tileMouse.pressed ? TuiStyle.surfacePressed
                : tile.active ? TuiStyle.panelAlt
                : tileMouse.containsMouse ? TuiStyle.surfaceHover
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
            color: TuiStyle.line
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
                color: tile.active ? TuiStyle.accent
                    : tile.engaged ? tile.tone
                    : TuiStyle.dim
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
                color: tile.active ? TuiStyle.fg
                    : tile.engaged ? TuiStyle.fg
                    : TuiStyle.dim
            }
        }
    }

    Component {
        id: scheduleContent
        Item {
            width: parent?.width ?? implicitWidth
            implicitHeight: scheduleHub.implicitHeight

            BottomWidgetGroup {
                id: scheduleHub
                anchors.horizontalCenter: parent.horizontalCenter
                popupMode: true
            }
        }
    }

    Component {
        id: voiceContent
        PopupColumn {
            id: voicePanel

            function stateLabel() {
                if (VoiceInput.state === "setup") return "未安装";
                if (VoiceInput.state === "idle") return "就绪";
                if (VoiceInput.state === "recording") return "录音中";
                if (VoiceInput.state === "transcribing") return "转写中";
                if (VoiceInput.state === "success") return "完成";
                if (VoiceInput.state === "error") return "错误";
                return VoiceInput.state;
            }
            function tone() {
                if (VoiceInput.state === "idle" || VoiceInput.state === "success") return TuiStyle.success;
                if (VoiceInput.state === "recording") return TuiStyle.danger;
                if (VoiceInput.state === "error") return TuiStyle.danger;
                if (VoiceInput.state === "transcribing" || VoiceInput.state === "setup") return TuiStyle.warning;
                return TuiStyle.muted;
            }

            Header { title: "VOICE INPUT"; status: voicePanel.stateLabel().toUpperCase(); tone: voicePanel.tone() }

            // ── 模型状态 ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: modelCol.implicitHeight + 16
                color: TuiStyle.panel
                border.width: 0
                radius: TuiStyle.radius
                clip: true

                ColumnLayout {
                    id: modelCol
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    StyledText {
                        text: "MODEL STATUS"
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Bold
                        color: TuiStyle.dim
                    }

                    TuiDetailRow {
                        keyText: "MODEL"
                        valueText: VoiceInput.modelSizeMB > 0 ? `SenseVoice Small (${VoiceInput.modelSizeMB} MB)` : "missing"
                        valueColor: VoiceInput.modelSizeMB > 0 ? TuiStyle.success : TuiStyle.danger
                    }

                    TuiDetailRow {
                        keyText: "STATUS"
                        valueText: VoiceInput.daemonRunning ? "Active (RAM Loaded)" : "Standby (0 RAM)"
                        valueColor: VoiceInput.daemonRunning ? TuiStyle.success : TuiStyle.muted
                    }

                    TuiDetailRow {
                        keyText: "VENV"
                        valueText: VoiceInput.state === "setup" ? "missing" : "ready"
                        valueColor: VoiceInput.state === "setup" ? TuiStyle.danger : TuiStyle.success
                    }

                    // 路径栏
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        StyledText {
                            text: "MODEL PATH"
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.smaller - 2
                            font.weight: Font.Bold
                            color: TuiStyle.dim
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: VoiceInput.modelDir
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.smaller - 1
                            color: TuiStyle.muted
                            elide: Text.ElideLeft
                        }
                    }
                }
            }

            // ── 调试测试面板 ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: debugCol.implicitHeight + 16
                color: TuiStyle.panel
                border.width: 0
                radius: TuiStyle.radius
                clip: true
                visible: VoiceInput.state !== "setup"

                ColumnLayout {
                    id: debugCol
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    StyledText {
                        text: "DEBUG TEST"
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Bold
                        color: TuiStyle.dim
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            id: debugRecBtn
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 64
                            radius: 32
                            color: VoiceInput.state === "recording" ? TuiStyle.danger : recMouse.containsMouse ? TuiStyle.surfaceHover : TuiStyle.surfaceRaised
                            border.width: 2
                            border.color: VoiceInput.state === "recording" ? TuiStyle.danger : recMouse.containsMouse ? TuiStyle.accent : TuiStyle.line

                            Behavior on scale {
                                NumberAnimation { duration: 120 }
                            }
                            scale: VoiceInput.state === "recording" ? 1.08 : 1.0

                            NerdIcon {
                                anchors.centerIn: parent
                                iconSize: 32
                                text: VoiceInput.state === "recording" ? NerdIconMap.stop : NerdIconMap.mic
                                color: VoiceInput.state === "recording" ? TuiStyle.bg : recMouse.containsMouse ? TuiStyle.fg : TuiStyle.muted
                            }

                            MouseArea {
                                id: recMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: VoiceInput.state === "idle" || VoiceInput.state === "recording"
                                onClicked: {
                                    if (VoiceInput.state === "recording") {
                                        VoiceInput.stopRecording()
                                    } else if (VoiceInput.state === "idle") {
                                        VoiceInput.testRecording()
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

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
                                maximumLineCount: 4
                                elide: Text.ElideRight
                                font.family: Appearance.font.family.main
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: VoiceInput.lastError ? TuiStyle.danger : TuiStyle.fg
                            }
                        }
                    }

                        ActionRow {
                            TuiActionButton {
                                label: "COPY TEXT"
                                accent: TuiStyle.info
                                enabled: VoiceInput.lastTranscription.length > 0
                                onClicked: {
                                    Quickshell.execDetached(["bash", "-c",
                                        `printf '%s' '${StringUtils.shellSingleQuoteEscape(VoiceInput.lastTranscription)}' | wl-copy`])
                                    VoiceInput.notify("Copied", VoiceInput.lastTranscription, "edit-copy")
                                }
                            }
                            TuiActionButton {
                                label: "COPY & PASTE"
                                accent: TuiStyle.accent
                                enabled: VoiceInput.lastTranscription.length > 0
                                onClicked: {
                                    Quickshell.execDetached(["bash", "-c",
                                        `printf '%s' '${StringUtils.shellSingleQuoteEscape(VoiceInput.lastTranscription)}' | wl-copy && ` +
                                        `'${VoiceInput.shareDir}/omd-paste-at-cursor' auto`])
                                }
                            }
                        }
                }
            }

            // ── 识别历史 ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(historyList.implicitHeight + 16, 220)
                color: TuiStyle.panel
                border.width: 0
                radius: TuiStyle.radius
                clip: true
                visible: VoiceInput.history.length > 0

                ColumnLayout {
                    id: historyList
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    StyledText {
                        text: `HISTORY (${VoiceInput.history.length})`
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Bold
                        color: TuiStyle.dim
                    }

                    ColumnLayout {
                        spacing: 0

                        Repeater {
                            model: VoiceInput.history
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 28
                                color: histMouse.containsMouse ? TuiStyle.panelAlt : "transparent"
                                clip: true

                                MouseArea {
                                    id: histMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Quickshell.execDetached(["bash", "-c",
                                            `printf '%s' '${StringUtils.shellSingleQuoteEscape(modelData.text)}' | wl-copy`])
                                        root.close();
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    spacing: 8

                                    StyledText {
                                        text: modelData.time
                                        font.family: Appearance.font.family.monospace
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: TuiStyle.dim
                                        Layout.preferredWidth: 36
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

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: TuiStyle.borderWidth
                                    color: TuiStyle.line
                                    opacity: 0.5
                                }
                            }
                        }
                    }
                }
            }

            // ── 操作按钮 ──
            ActionRow {
                TuiActionButton {
                    label: VoiceInput.state === "setup" ? "安装" : "测试"
                    accent: TuiStyle.info
                    onClicked: {
                        if (VoiceInput.state === "setup") {
                            VoiceInput.setup();
                        } else if (VoiceInput.state === "idle") {
                            VoiceInput.testRecording();
                        }
                        root.close();
                    }
                }

                TuiActionButton {
                    label: "检查"
                    accent: TuiStyle.accent
                    onClicked: {
                        VoiceInput.checkState();
                        VoiceInput.refreshModelInfo();
                        VoiceInput.refreshDaemonStatus();
                    }
                }

                TuiActionButton {
                    label: "清除"
                    accent: TuiStyle.danger
                    visible: VoiceInput.history.length > 0
                    onClicked: VoiceInput.clearHistory()
                }
            }
        }
    }
}
