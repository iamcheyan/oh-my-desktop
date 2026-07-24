import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import qs.modules.settings
import qs.modules.settings.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.modules.popupComponents

PopupColumn {
    id: batteryStack
    width: parent?.width ?? implicitWidth

    property bool hibernateAvailable: false
    readonly property var brightnessMonitor: Brightness.getMonitorForScreen(
        Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    )
    readonly property real brightnessValue: brightnessMonitor?.brightness ?? 0
    readonly property int chargeLimit: Config.options.battery.full ?? 100

    function stateLabel() {
        if (!ServiceManager.power.battery.available) return "desktop";
        if (ServiceManager.power.battery.isCharging) return "charging";
        if (ServiceManager.power.battery.isPluggedIn) return "plugged";
        return "battery";
    }

    function headerTitle() {
        return ServiceManager.power.battery.available ? "BATTERY" : "POWER";
    }

    function headerStatus() {
        if (!ServiceManager.power.battery.available) return "DESKTOP";
        return `${Math.round(ServiceManager.power.battery.percentage * 100)}%`;
    }

    function headerTone() {
        if (!ServiceManager.power.battery.available) return TuiStyle.accent;
        if (ServiceManager.power.battery.isLowAndNotCharging) return TuiStyle.danger;
        if (ServiceManager.power.battery.isCharging) return TuiStyle.warning;
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
        const timeValue = ServiceManager.power.battery.isCharging ? ServiceManager.power.battery.timeToFull : ServiceManager.power.battery.timeToEmpty;
        const power = ServiceManager.power.battery.energyRate;
        return ServiceManager.power.battery.available
            && !(ServiceManager.power.battery.chargeState === 4 || timeValue <= 0 || power <= 0.01);
    }

    function timeEstimateLabel() {
        return ServiceManager.power.battery.isCharging ? "TIME TO FULL" : "TIME LEFT";
    }

    function timeEstimateValue() {
        const seconds = ServiceManager.power.battery.isCharging ? ServiceManager.power.battery.timeToFull : ServiceManager.power.battery.timeToEmpty;
        return formatDuration(seconds);
    }

    function timeEstimateColor() {
        if (ServiceManager.power.battery.isLowAndNotCharging) return TuiStyle.danger;
        if (ServiceManager.power.battery.isCharging) return TuiStyle.warning;
        return TuiStyle.muted;
    }

    function profileLabel() {
        const profile = ServiceManager.power.powerProfiles.currentProfile;
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
        icon: ServiceManager.power.battery.available ? NerdIconMap.batteryFull : NerdIconMap.power
        title: ServiceManager.power.battery.available ? "Power & Battery" : "Power"
        subtitle: batteryStack.headerStatus() + (batteryStack.showTimeEstimate() ? "  ·  " + batteryStack.timeEstimateValue() + " remaining" : "")
        tone: batteryStack.headerTone()
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: ServiceManager.power.battery.available ? 24 : 0
        spacing: 12
        visible: ServiceManager.power.battery.available

        TuiMeterBar {
            Layout.fillWidth: true
            Layout.preferredHeight: 10
            Layout.alignment: Qt.AlignVCenter
            value: ServiceManager.power.battery.percentage * 100
            accent: ServiceManager.power.battery.isLowAndNotCharging ? TuiStyle.danger : ServiceManager.power.battery.isCharging ? TuiStyle.warning : TuiStyle.success
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: `${Math.round(ServiceManager.power.battery.percentage * 100)}%`
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: ServiceManager.power.battery.isLowAndNotCharging ? TuiStyle.danger : TuiStyle.fg
        }
    }

    TuiDetailRow {
        visible: ServiceManager.power.battery.available
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
        visible: ServiceManager.power.battery.available && ServiceManager.power.battery.chargeState !== 4 && ServiceManager.power.battery.energyRate > 0.01
        keyText: "POWER DRAW"
        valueText: `${ServiceManager.power.battery.energyRate.toFixed(1)}W`
        valueColor: ServiceManager.power.battery.isCharging ? TuiStyle.warning : TuiStyle.info
        keyWidth: 96
    }

    SectionLabel {
        visible: ServiceManager.power.powerProfiles.available
        text: "POWER PROFILE"
        topInset: ServiceManager.power.battery.available ? 4 : 0
    }

    // ── Power Profile — vertical list, GNOME style ───────────────
    Item {
        Layout.fillWidth: true
        visible: ServiceManager.power.powerProfiles.available
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
                    readonly property bool isActive: ServiceManager.power.powerProfiles.currentProfile === modelData.id

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
                        onClicked: ServiceManager.power.powerProfiles.setProfile(modelData.id)
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
            visible: LockService.lockHandler !== null
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

    // ── Shared tile chrome ──
    readonly property color tileTrackBorder: Qt.rgba(TuiStyle.line.r, TuiStyle.line.g, TuiStyle.line.b, 0.22)

    component TileTrack: Rectangle {
        id: track
        default property alias cells: cellRow.data

        Layout.fillWidth: true
        Layout.preferredHeight: 50
        implicitHeight: 50
        radius: SettingsTokens.radius
        color: SettingsTokens.button
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
            spacing: 2

            NerdIcon {
                iconSize: 16
                text: tile.icon
                color: tile.engaged ? tile.tone : TuiStyle.dim
                Layout.alignment: Qt.AlignHCenter
            }

            StyledText {
                text: tile.label
                color: tile.engaged ? tile.tone : TuiStyle.dim
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}