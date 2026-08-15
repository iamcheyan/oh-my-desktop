pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.bar
import qs.services
import qs.core.runtime
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower

// Power & Battery popup content. BarStatusPopup owns the outer shell.
Item {
    id: batteryStack
    default property alias content: cardColumn.data

    Layout.fillWidth: true
    implicitWidth: parent?.width ?? 0
    implicitHeight: visible ? cardColumn.implicitHeight : 0
    height: implicitHeight
    visible: true

    // ── Battery state ─────────────────────────────────────────────
    property bool hibernateAvailable: false
    readonly property var brightnessMonitor: Brightness.getMonitorForScreen(
        Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    )
    readonly property real brightnessValue: brightnessMonitor?.brightness ?? 0
    readonly property int chargeLimit: Config.options.battery.full ?? 100
    property bool keepAwakeEnabled: false

    function stateLabel() {
        if (!ServiceManager?.power?.battery?.available) return "desktop";
        if (ServiceManager.power.battery.isCharging) return "charging";
        if (ServiceManager.power.battery.isPluggedIn) return "plugged";
        return "battery";
    }

    function headerTitle() {
        return ServiceManager?.power?.battery?.available ? "BATTERY" : "POWER";
    }

    function headerStatus() {
        if (!ServiceManager?.power?.battery?.available) return "DESKTOP";
        return `${Math.round(ServiceManager.power.battery.percentage * 100)}%`;
    }

    function headerTone() {
        if (!ServiceManager?.power?.battery?.available) return TuiStyle.accent;
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
        return TuiStyle.fg;
    }

    function profileLabel() {
        const profile = ServiceManager.power.powerProfiles.currentProfile;
        if (profile === "performance") return "performance";
        if (profile === "balanced") return "balanced";
        if (profile === "power-saver") return "power saver";
        return profile;
    }

    function toggleKeepAwake() {
        const next = !keepAwakeEnabled;
        keepAwakeEnabled = next; // optimistic: poll converges with real state
        Quickshell.execDetached([`${Directories.root}/bin/sumika-keep-awake`, next ? "on" : "off"]);
    }

    function executeAction(action) {
        GlobalStates.barPopupType = "";
        const actionId = action === "lock" ? "session.lock"
            : action === "sleep" ? "session.suspend"
            : action === "hibernate" ? "session.hibernate"
            : action === "logout" ? "session.logout"
            : action === "reboot" ? "session.reboot"
            : action === "poweroff" ? "session.shutdown"
            : null;
        if (actionId) {
            ActionManager.invoke(actionId);
        }
    }

    function requestAction(action, label) {
        if (action === "lock" || action === "sleep" || action === "hibernate") {
            executeAction(action)
            return
        }
        GlobalStates.requestSessionConfirm(action, label)
        GlobalStates.barPopupType = ""
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

    FileView {
        id: keepAwakeState
        path: `${Directories.sumikaStateHome}/keep-awake`
        watchChanges: true
        onLoaded: batteryStack.keepAwakeEnabled = text().trim() === "on"
        onLoadFailed: batteryStack.keepAwakeEnabled = false
    }

    // watchChanges does not fire on file create/delete (the script writes and
    // removes the state file), so poll to converge with the real state.
    Timer {
        id: keepAwakePoll
        interval: 2000
        running: true
        repeat: true
        onTriggered: keepAwakeState.reload()
    }

    // Transparent content host. Popup chrome is centralized in BarStatusPopup.
    Rectangle {
        id: cardBg
        anchors {
            left: parent.left; right: parent.right; top: parent.top
        }
        color: "transparent"
        radius: 0
        border.width: 0
        clip: true
        implicitHeight: cardColumn.implicitHeight
        height: implicitHeight

        ColumnLayout {
            id: cardColumn
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                margins: 0
            }
            spacing: 0

            // ── Header ───────────────────────────────────────────
            PopupHeader {
                Layout.fillWidth: true
                icon: ServiceManager?.power?.battery?.available ? NerdIconMap.batteryFull : NerdIconMap.power
                title: ServiceManager?.power?.battery?.available ? "Power & Battery" : "Power"
                subtitle: batteryStack.headerStatus() + (batteryStack.showTimeEstimate() ? "  ·  " + batteryStack.timeEstimateValue() + " remaining" : "")
                tone: batteryStack.headerTone()
                actionIcon: "settings"
                actionTooltip: "编辑配置文件"
                onActionClicked: {
                    Quickshell.execDetached(["sumika-config-edit"]);
                }
            }

            // ── Battery meter bar ────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                Layout.preferredHeight: ServiceManager.power.battery.available ? 24 : 0
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
                    color: ServiceManager.power.battery.isLowAndNotCharging ? TuiStyle.danger : TuiStyle.fg
                }
            }

            // ── Detail rows ──────────────────────────────────────
            TuiDetailRow {
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                visible: batteryStack.showTimeEstimate()
                keyText: batteryStack.timeEstimateLabel()
                valueText: batteryStack.timeEstimateValue()
                valueColor: batteryStack.timeEstimateColor()
                keyWidth: 96
            }

            TuiDetailRow {
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                visible: ServiceManager.power.battery.available && ServiceManager.power.battery.chargeState !== 4 && ServiceManager.power.battery.energyRate > 0.01
                valueText: `${ServiceManager.power.battery.energyRate.toFixed(1)}W`
                valueColor: ServiceManager.power.battery.isCharging ? TuiStyle.warning : TuiStyle.info
                keyWidth: 96
            }

            // ── Power Profile ───────────────────────────────────────
            SectionLabel {
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                text: "POWER PROFILE"
                visible: ServiceManager?.power?.powerProfiles?.available ?? false
                topInset: 6
                bottomInset: 2
            }

            Item {
                Layout.fillWidth: true
                visible: ServiceManager?.power?.powerProfiles?.available ?? false
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
                            implicitHeight: 56

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
                                onClicked: {
                                    // 档位驱动显示特效：performance/power-saver → 全关特效
                                    // （省电也要 GPU 少干活），balanced → 轻特效。
                                    // settings 显示页的开关保留为手动覆盖。
                                    const profile = modelData.id;
                                    if (profile === "performance" || profile === "power-saver") {
                                        Persistent.states.display = Persistent.states.display || {};
                                        Persistent.states.display.optimization = "performance";
                                    } else if (profile === "balanced") {
                                        Persistent.states.display = Persistent.states.display || {};
                                        Persistent.states.display.optimization = "balanced";
                                    }
                                    Persistent.applyDisplayOptimization();
                                    ServiceManager.power.powerProfiles.setProfile(profile);
                                }
                            }
                        }
                    }
                }
            }

            // ── Keep Awake (long-task) mode ─────────────────────────
            SectionLabel {
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                text: "KEEP AWAKE"
                topInset: 6
                bottomInset: 2
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: 56

                RowLayout {
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
                        text: NerdIconMap.keepAwake
                        color: batteryStack.keepAwakeEnabled ? TuiStyle.accent : TuiStyle.dim
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: "Keep Awake"
                            font.family: Appearance.font.family.main
                            font.pixelSize: Appearance.font.pixelSize.normal + 1
                            font.weight: Font.Medium
                            color: TuiStyle.fg
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: "Lid close won't suspend — long tasks keep running"
                            font.family: Appearance.font.family.main
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: TuiStyle.dim
                            elide: Text.ElideRight
                        }
                    }

                    // Switch
                    Rectangle {
                        width: 46
                        height: 26
                        radius: height / 2
                        color: batteryStack.keepAwakeEnabled ? TuiStyle.accent : TuiStyle.control

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            anchors.verticalCenter: parent.verticalCenter
                            x: batteryStack.keepAwakeEnabled ? parent.width - width - 3 : 3
                            color: batteryStack.keepAwakeEnabled ? TuiStyle.bg : TuiStyle.fg
                            Behavior on x { NumberAnimation { duration: 110 } }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: batteryStack.toggleKeepAwake()
                }
            }

            // ── Section 1: Power Controls (4-Column Equal-Width Row) ──
            SectionLabel {
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                text: "SYSTEM CONTROLS"
                topInset: 6
                bottomInset: 2
            }

            IconActionRow {
                PopupIconButtonDark {
                    icon: "lock"
                    label: "Lock"
                    visible: LockService.lockHandler !== null
                    hoverAccent: TuiStyle.accent
                    onClicked: batteryStack.requestAction("lock", "Lock")
                }
                PopupIconButtonDark {
                    icon: "dark_mode"
                    label: "Sleep"
                    hoverAccent: TuiStyle.info
                    onClicked: batteryStack.requestAction("sleep", "Sleep")
                }
                PopupIconButtonDark {
                    icon: "download"
                    label: "Hibernate"
                    visible: batteryStack.hibernateAvailable
                    hoverAccent: TuiStyle.accent
                    onClicked: batteryStack.requestAction("hibernate", "Hibernate")
                }
                PopupIconButtonDark {
                    icon: "restart_alt"
                    label: "Reboot"
                    hoverAccent: TuiStyle.warning
                    hoverColor: Qt.rgba(0.95, 0.6, 0.1, 0.15)
                    onClicked: batteryStack.requestAction("reboot", "Reboot")
                }
                PopupIconButtonDark {
                    icon: "power_settings_new"
                    label: "Shut Down"
                    hoverAccent: TuiStyle.danger
                    hoverColor: Qt.rgba(0.95, 0.25, 0.25, 0.18)
                    onClicked: batteryStack.requestAction("poweroff", "Shutdown")
                }
            }

            // ── Section 2: Session & Utilities (2-Column Grid) ──
            SectionLabel {
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                text: "SESSION & UTILITIES"
                topInset: 6
                bottomInset: 2
            }

            IconActionRow {
                PopupIconButtonDark {
                    icon: "logout"
                    label: "Log Out"
                    onClicked: batteryStack.requestAction("logout", "Logout")
                }
                PopupIconButtonDark {
                    icon: "refresh"
                    label: "Reload Shell"
                    onClicked: {
                        Quickshell.execDetached(["bash", `${Directories.root}/bin/sumika-restart`]);
                        GlobalStates.barPopupType = "";
                    }
                }
            }



            // Bottom spacer — consistent with top padding
            Item {
                Layout.preferredHeight: 12
            }
        }
    }
}

