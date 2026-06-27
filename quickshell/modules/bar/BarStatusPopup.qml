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

    Loader {
        id: popupLoader
        active: root.open && root.focusedScreen

        sourceComponent: PanelWindow {
            id: popupWindow
            screen: root.focusedScreen
            visible: popupLoader.active
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:barstatus"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.activeType === "schedule" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            readonly property bool barOnBottom: Config.options.bar.bottom
            readonly property bool large: root.activeType === "schedule"
            readonly property int panelWidth: large ? Math.min(Appearance.sizes.sidebarWidth, Math.max(520, (screen?.width ?? 1920) - 32)) : 348

            anchors {
                top: !barOnBottom
                bottom: barOnBottom
                right: true
            }

            margins {
                top: barOnBottom ? 0 : Appearance.sizes.barHeight
                bottom: barOnBottom ? Appearance.sizes.barHeight : 0
                right: 8
            }

            implicitWidth: panel.implicitWidth
            implicitHeight: panel.implicitHeight

            mask: Region {
                item: panel
            }

            Component.onCompleted: GlobalFocusGrab.addDismissable(popupWindow)
            Component.onDestruction: GlobalFocusGrab.removeDismissable(popupWindow)

            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    root.close();
                }
            }

            StyledRectangularShadow {
                target: panelBg
            }

            Item {
                id: panel
                anchors.right: parent.right
                implicitWidth: panelBg.implicitWidth
                implicitHeight: panelBg.implicitHeight

                Rectangle {
                    id: panelBg
                    implicitWidth: popupWindow.panelWidth
                    implicitHeight: contentLoader.implicitHeight + 24
                    color: TuiStyle.bg
                    border.width: TuiStyle.borderWidth
                    border.color: TuiStyle.line
                    radius: TuiStyle.radius
                    clip: true

                    Loader {
                        id: contentLoader
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        sourceComponent: {
                            if (root.activeType === "wifi") return wifiContent;
                            if (root.activeType === "bluetooth") return bluetoothContent;
                            if (root.activeType === "audio") return audioContent;
                            if (root.activeType === "display") return displayContent;
                            if (root.activeType === "battery") return batteryContent;
                            if (root.activeType === "clipboard") return clipboardContent;
                            if (root.activeType === "resources") return resourcesContent;
                            if (root.activeType === "schedule") return scheduleContent;
                            return emptyContent;
                        }
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
        Layout.preferredHeight: 40
        color: TuiStyle.panel
        border.width: TuiStyle.borderWidth
        border.color: tone

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 8

            StyledText {
                text: header.title
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Bold
                color: TuiStyle.accent
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: TuiStyle.borderWidth
                color: TuiStyle.line
            }

            StyledText {
                text: header.status
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Bold
                color: header.tone
            }
        }
    }

    component PopupColumn: ColumnLayout {
        spacing: 14
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
            function stateLabel() {
                if (!Battery.available) return "unavailable";
                if (Battery.isCharging) return "charging";
                if (Battery.isPluggedIn) return "plugged";
                return "battery";
            }

            Header { title: "BATTERY"; status: stateLabel().toUpperCase(); tone: Battery.isLowAndNotCharging ? TuiStyle.danger : Battery.isCharging ? TuiStyle.warning : TuiStyle.success }
            TuiMeterBar { Layout.fillWidth: true; Layout.preferredHeight: 10; value: Battery.available ? Battery.percentage * 100 : 0; accent: Battery.isLowAndNotCharging ? TuiStyle.danger : Battery.isCharging ? TuiStyle.warning : TuiStyle.success }
            TuiDetailRow { keyText: "LEVEL"; valueText: Battery.available ? `${Math.round(Battery.percentage * 100)}%` : "--"; valueColor: Battery.isLowAndNotCharging ? TuiStyle.danger : TuiStyle.fg }
            TuiDetailRow { keyText: "RATE"; valueText: Battery.available ? `${Battery.energyRate.toFixed(1)}W` : "--"; valueColor: TuiStyle.info }
            TuiDetailRow { keyText: "HEALTH"; valueText: Battery.available && Battery.health > 0 ? `${Battery.health.toFixed(1)}%` : "--"; valueColor: Battery.health > 0 && Battery.health < 80 ? TuiStyle.warning : TuiStyle.success }
            TuiDetailRow { keyText: "PROFILE"; valueText: PowerProfiles.available ? PowerProfiles.currentProfile : "unavailable"; valueColor: TuiStyle.muted }
            ActionRow {
                TuiActionButton {
                    label: "POWER"
                    onClicked: {
                        root.close();
                        GlobalStates.controlCenterOpen = true;
                    }
                }
            }
        }
    }

    Component {
        id: clipboardContent
        PopupColumn {
            readonly property bool ready: Cliphist.entries.length > 0 || Cliphist.cliphistBinary.length > 0
            Header { title: "CLIPBOARD"; status: ready ? "READY" : "UNAVAILABLE"; tone: ready ? TuiStyle.success : TuiStyle.danger }
            TuiDetailRow { keyText: "SERVICE"; valueText: Cliphist.cliphistBinary; valueColor: TuiStyle.muted }
            TuiDetailRow { keyText: "ENTRIES"; valueText: `${Cliphist.entries.length}`; valueColor: TuiStyle.info }
            TuiDetailRow { keyText: "DELAY"; valueText: `${Math.round(Cliphist.pasteDelay * 1000)}ms`; valueColor: TuiStyle.muted }
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
}
