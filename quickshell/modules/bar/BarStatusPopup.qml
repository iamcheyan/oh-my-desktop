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
        readonly property int panelWidth: Math.min(440, (screen?.width ?? 1920) - 32)

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
                implicitHeight: Math.max(
                    contentLoader.implicitHeight,
                    modulePopupActiveHeight
                ) + contentPadding * 2
                contentPadding: 0
                useLayerMask: false
                color: panel.multiShell ? "transparent" : TuiStyle.bg
                border.width: panel.multiShell ? 0 : TuiStyle.borderWidth
                border.color: TuiStyle.menuBorder
                radius: panel.multiShell ? 0 : TuiStyle.shellRadius
                clip: !panel.multiShell

                // Tracks the height of the active module-registered popup section
                property int modulePopupActiveHeight: 0

                Loader {
                    id: contentLoader
                    anchors.fill: parent
                    sourceComponent: {
                        if (root.activeType === "wifi") return wifiContent;
                        if (root.activeType === "bluetooth") return bluetoothContent;
                        if (root.activeType === "audio") return audioContent;


                        if (root.activeType === "notifications") return notificationsContent;



                        if (root.activeType === "xkb") return xkbContent;
                        return emptyContent;
                    }
                }

                // Module-registered popup sections
                Repeater {
                    model: ModuleLoader.popupSections

                    delegate: Loader {
                        id: modulePopupLoader
                        anchors.fill: parent
                        active: root.activeType === modelData.type
                        source: modelData.component
                        onLoaded: if (active) panelBg.modulePopupActiveHeight = implicitHeight
                        onImplicitHeightChanged: if (active) panelBg.modulePopupActiveHeight = implicitHeight
                        onActiveChanged: if (!active) panelBg.modulePopupActiveHeight = 0
                        onStatusChanged: if (status === Loader.Error) {
                            console.warn("[Module] Popup section load error:", modelData.component)
                            active = false
                        }
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

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        text: "settings"
                        iconSize: 20
                        color: mutedSettingsMouse.containsMouse ? TuiStyle.fg : TuiStyle.dim

                        MouseArea {
                            id: mutedSettingsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.close();
                                Notifications.openMutedAppsEditor();
                            }
                        }
                    }

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

}
