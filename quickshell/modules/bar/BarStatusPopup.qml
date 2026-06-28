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

    function openDialog(dialogType, isSink) {
        root.close();
        if (isSink !== undefined)
            GlobalStates.barAudioIsSink = isSink;
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
        WlrLayershell.keyboardFocus: root.activeType === "schedule" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        readonly property bool barOnBottom: Config.options.bar.bottom
        readonly property bool large: root.activeType === "schedule"
        readonly property int panelWidth: large ? Math.min(Appearance.sizes.sidebarWidth, Math.max(520, (screen?.width ?? 1920) - 32)) : 360

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

        mask: Region {
            item: panel
        }

        Timer {
            id: dismissGuard
            interval: 150
            repeat: false
            onTriggered: GlobalFocusGrab.addDismissable(popupWindow)
        }

        onVisibleChanged: {
            console.log(`[BarStatusPopup] visible=${visible} activeType=${root.activeType} size=${implicitWidth}x${implicitHeight} screen=${screen?.name}`);
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
            implicitWidth: panelBg.implicitWidth
            implicitHeight: panelBg.implicitHeight
            width: implicitWidth
            height: implicitHeight

            StyledRectangularShadow {
                target: panelBg
            }

            TuiShell {
                id: panelBg
                implicitWidth: popupWindow.panelWidth
                implicitHeight: contentLoader.implicitHeight + contentPadding * 2
                width: implicitWidth
                height: implicitHeight

                Loader {
                    id: contentLoader
                    anchors.fill: parent
                    sourceComponent: {
                        if (root.activeType === "wifi") return wifiContent;
                        if (root.activeType === "bluetooth") return bluetoothContent;
                        if (root.activeType === "audio") return audioContent;
                        if (root.activeType === "display") return displayContent;
                        if (root.activeType === "battery") return batteryContent;
                        if (root.activeType === "clipboard") return clipboardContent;
                        if (root.activeType === "resources") return resourcesContent;
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
                color: TuiStyle.fg
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: TuiStyle.borderWidth
            color: TuiStyle.line
            opacity: 0.28
        }
    }

    component PopupColumn: ColumnLayout {
        spacing: 10
        width: parent?.width ?? implicitWidth
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
                TuiActionButton { label: "AUDIOCTL"; onClicked: root.openDialog("audio", true) }
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
        PopupColumn {
            id: batteryPanel
            function stateLabel() {
                if (!Battery.available) return "unavailable";
                if (Battery.isCharging) return "charging";
                if (Battery.isPluggedIn) return "plugged";
                return "battery";
            }
            property string confirmAction: ""
            property string confirmLabel: ""
            property bool hibernateAvailable: false

            Component.onCompleted: {
                hibernateCheck.running = true
            }

            Process {
                id: hibernateCheck
                command: ["bash", "-c", "grep -q disk /sys/power/state && echo YES || echo NO"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        batteryPanel.hibernateAvailable = text.trim() === "YES"
                    }
                }
            }

            function executeAction(action) {
                if (action === "lock") { Session.lock(); root.close(); return; }
                if (action === "sleep") { Session.suspend(); root.close(); return; }
                if (action === "hibernate") { Session.hibernate(); root.close(); return; }
                if (action === "logout") { Session.logout(); root.close(); return; }
                if (action === "reboot") { Session.reboot(); root.close(); return; }
                if (action === "poweroff") { Session.poweroff(); root.close(); return; }
            }

            function requestAction(action, label) {
                if (action === "lock" || action === "sleep" || action === "hibernate" || action === "logout") {
                    executeAction(action)
                    return
                }
                confirmAction = action
                confirmLabel = label
            }

            function cancelConfirm() {
                confirmAction = ""
                confirmLabel = ""
            }

            Header { title: "BATTERY"; status: stateLabel().toUpperCase(); tone: Battery.isLowAndNotCharging ? TuiStyle.danger : Battery.isCharging ? TuiStyle.warning : TuiStyle.success }
            TuiMeterBar { Layout.fillWidth: true; Layout.preferredHeight: 10; value: Battery.available ? Battery.percentage * 100 : 0; accent: Battery.isLowAndNotCharging ? TuiStyle.danger : Battery.isCharging ? TuiStyle.warning : TuiStyle.success }
            TuiDetailRow { keyText: "LEVEL"; valueText: Battery.available ? `${Math.round(Battery.percentage * 100)}%` : "--"; valueColor: Battery.isLowAndNotCharging ? TuiStyle.danger : TuiStyle.fg }
            TuiDetailRow { keyText: "RATE"; valueText: Battery.available ? `${Battery.energyRate.toFixed(1)}W` : "--"; valueColor: TuiStyle.info }
            TuiDetailRow { keyText: "HEALTH"; valueText: Battery.available && Battery.health > 0 ? `${Battery.health.toFixed(1)}%` : "--"; valueColor: Battery.health > 0 && Battery.health < 80 ? TuiStyle.warning : TuiStyle.success }
            TuiDetailRow { keyText: "PROFILE"; valueText: PowerProfiles.available ? PowerProfiles.currentProfile : "unavailable"; valueColor: TuiStyle.muted }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: TuiStyle.borderWidth
                color: TuiStyle.line
            }

            // Session controls
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                color: "transparent"
                visible: confirmAction === ""

                StyledText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SESSION"
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Bold
                    color: TuiStyle.dim
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                color: TuiStyle.panel
                border.width: 0
                radius: TuiStyle.radius
                clip: true
                visible: confirmAction === ""

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    PowerButton {
                        icon: "lock"
                        label: "LOCK"
                        tone: TuiStyle.accent
                        onClicked: batteryPanel.requestAction("lock", "Lock")
                    }
                    Rectangle { width: TuiStyle.borderWidth; Layout.fillHeight: true; color: TuiStyle.line }
                    PowerButton {
                        icon: "dark_mode"
                        label: "SLEEP"
                        tone: TuiStyle.info
                        onClicked: batteryPanel.requestAction("sleep", "Sleep")
                    }
                    Rectangle { width: TuiStyle.borderWidth; Layout.fillHeight: true; color: TuiStyle.line }
                    PowerButton {
                        icon: "downloading"
                        label: "HIBERNATE"
                        tone: TuiStyle.purple
                        visible: batteryPanel.hibernateAvailable
                        onClicked: batteryPanel.requestAction("hibernate", "Hibernate")
                    }
                    Rectangle { width: TuiStyle.borderWidth; Layout.fillHeight: true; color: TuiStyle.line; visible: batteryPanel.hibernateAvailable }
                    PowerButton {
                        icon: "logout"
                        label: "LOGOUT"
                        tone: TuiStyle.warning
                        onClicked: batteryPanel.requestAction("logout", "Logout")
                    }
                    Item { Layout.fillWidth: true }
                }
            }

            // Power controls
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                color: "transparent"
                visible: confirmAction === ""

                StyledText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "POWER"
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Bold
                    color: TuiStyle.dim
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                color: TuiStyle.panel
                border.width: 0
                radius: TuiStyle.radius
                clip: true
                visible: confirmAction === ""

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    PowerButton {
                        icon: "restart_alt"
                        label: "REBOOT"
                        tone: TuiStyle.info
                        onClicked: batteryPanel.requestAction("reboot", "Reboot")
                    }
                    Rectangle { width: TuiStyle.borderWidth; Layout.fillHeight: true; color: TuiStyle.line }
                    PowerButton {
                        icon: "power_settings_new"
                        label: "SHUTDOWN"
                        tone: TuiStyle.danger
                        onClicked: batteryPanel.requestAction("poweroff", "Shutdown")
                    }
                    Rectangle { width: TuiStyle.borderWidth; Layout.fillHeight: true; color: TuiStyle.line }
                    PowerButton {
                        icon: "refresh"
                        label: "RELOAD"
                        tone: TuiStyle.accent
                        onClicked: {
                            Quickshell.execDetached(["bash", `${FileUtils.trimFileProtocol(Directories.config)}/omd/scripts/reload-quickshell`]);
                            root.close();
                        }
                    }
                    Item { Layout.fillWidth: true }
                }
            }

            ActionRow {
                Layout.topMargin: 14
                visible: confirmAction === ""
                TuiActionButton {
                    label: "SETTINGS"
                    accent: TuiStyle.accent
                    onClicked: {
                        root.close();
                        GlobalStates.controlCenterOpen = true;
                    }
                }
            }

            // Confirm dialog
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: confirmCol.implicitHeight + 16
                color: TuiStyle.dangerPanel
                border.width: 0
                radius: TuiStyle.radius
                clip: true
                visible: confirmAction !== ""

                ColumnLayout {
                    id: confirmCol
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    StyledText {
                        Layout.fillWidth: true
                        text: `CONFIRM ${batteryPanel.confirmLabel.toUpperCase()}?`
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Bold
                        color: TuiStyle.danger
                        horizontalAlignment: Text.AlignHCenter
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Item { Layout.fillWidth: true }
                        TuiActionButton {
                            label: "CANCEL"
                            accent: TuiStyle.dim
                            onClicked: batteryPanel.cancelConfirm()
                        }
                        TuiActionButton {
                            label: "CONFIRM"
                            accent: TuiStyle.danger
                            onClicked: batteryPanel.executeAction(batteryPanel.confirmAction)
                        }
                    }
                }
            }
        }
    }

    component PowerButton: Item {
        id: pb
        property string icon: ""
        property string label: ""
        property color tone: TuiStyle.accent
        signal clicked()
        Layout.fillHeight: true
        Layout.preferredWidth: 80

        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: TuiStyle.radius
            color: pbMouseArea.containsMouse ? TuiStyle.controlHover : TuiStyle.control
            border.width: 0
            clip: true

            MouseArea {
                id: pbMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: pb.clicked()

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        iconSize: 22
                        text: pb.icon
                        color: pbMouseArea.containsMouse ? TuiStyle.fg : pb.tone
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: pb.label
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Medium
                        color: pbMouseArea.containsMouse ? TuiStyle.fg : TuiStyle.dim
                    }
                }
            }
        }
    }

    Component {
        id: clipboardContent
        PopupColumn {
            id: clipPanel
            readonly property bool ready: Cliphist.entries.length > 0 || Cliphist.cliphistBinary.length > 0
            readonly property var recentEntries: Cliphist.entries.slice(0, 10)
            Header { title: "CLIPBOARD"; status: ready ? "READY" : "UNAVAILABLE"; tone: ready ? TuiStyle.success : TuiStyle.danger }
            TuiDetailRow { keyText: "ENTRIES"; valueText: `${Cliphist.entries.length}`; valueColor: TuiStyle.info }

            // Recent entries — click to paste
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: recentList.implicitHeight + 8
                color: TuiStyle.panel
                border.width: 0
                radius: TuiStyle.radius
                clip: true
                visible: clipPanel.recentEntries.length > 0

                ColumnLayout {
                    id: recentList
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 0

                    Repeater {
                        model: clipPanel.recentEntries
                        delegate: Rectangle {
                            required property string modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            color: mouseArea.containsMouse ? TuiStyle.panelAlt : "transparent"
                            clip: true

                            readonly property bool isImage: Cliphist.entryIsImage(modelData)
                            readonly property int imgW: {
                                var m = modelData.match(/(\d+)x(\d+)/);
                                return m ? parseInt(m[1]) : 0;
                            }
                            readonly property int imgH: {
                                var m = modelData.match(/(\d+)x(\d+)/);
                                return m ? parseInt(m[2]) : 0;
                            }
                            readonly property string preview: isImage ? `[IMG] ${imgW}x${imgH}` : StringUtils.cleanCliphistEntry(modelData)

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Cliphist.paste(modelData);
                                    root.close();
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 6

                                StyledText {
                                    Layout.fillWidth: true
                                    text: parent.parent.preview
                                    elide: Text.ElideRight
                                    font.family: Appearance.font.family.monospace
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: mouseArea.containsMouse ? TuiStyle.fg : TuiStyle.muted
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

            ActionRow {
                TuiActionButton {
                    label: "HISTORY"
                    onClicked: {
                        root.close();
                        Quickshell.execDetached([
                            "qs", "-p", `${FileUtils.trimFileProtocol(Directories.config)}/omd/apps/omd-clipboard`,
                            "ipc", "call", "clipboard", "toggle"
                        ]);
                    }
                }
            }
        }
    }

    Component {
        id: resourcesContent
        PopupColumn {
            Header { title: "RESOURCES"; status: "LIVE"; tone: TuiStyle.accent }
            TuiDetailRow { keyText: "RAM"; valueText: `${Math.round(ResourceUsage.memoryUsedPercentage * 100)}%`; valueColor: TuiStyle.info }
            TuiDetailRow { keyText: "MEM USED"; valueText: `${(ResourceUsage.memoryUsed / (1024 * 1024)).toFixed(1)} GB`; valueColor: TuiStyle.fg }
            TuiDetailRow { keyText: "MEM FREE"; valueText: `${(ResourceUsage.memoryFree / (1024 * 1024)).toFixed(1)} GB`; valueColor: TuiStyle.muted }
            TuiDetailRow { keyText: "SWAP"; valueText: ResourceUsage.swapTotal > 0 ? `${(ResourceUsage.swapUsed / (1024 * 1024)).toFixed(1)} GB` : "none"; valueColor: TuiStyle.muted }
            TuiDetailRow { keyText: "CPU"; valueText: `${Math.round(ResourceUsage.cpuUsage * 100)}%`; valueColor: TuiStyle.warning }
        }
    }

    Component {
        id: scheduleContent
        BottomWidgetGroup {
            width: parent?.width ?? implicitWidth
            popupMode: true
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
                        valueText: VoiceInput.modelSizeMB > 0 ? `${VoiceInput.modelSizeMB} MB` : "missing"
                        valueColor: VoiceInput.modelSizeMB > 0 ? TuiStyle.success : TuiStyle.danger
                    }

                    TuiDetailRow {
                        keyText: "VENV"
                        valueText: VoiceInput.state === "setup" ? "missing" : "ready"
                        valueColor: VoiceInput.state === "setup" ? TuiStyle.danger : TuiStyle.success
                    }

                    TuiDetailRow {
                        keyText: "DAEMON"
                        valueText: VoiceInput.daemonRunning ? "running" : "stopped"
                        valueColor: VoiceInput.daemonRunning ? TuiStyle.success : TuiStyle.warning
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
