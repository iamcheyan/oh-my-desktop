pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.core.runtime
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

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

    onActiveTypeChanged: popupFlick.contentY = 0

    function close() {
        GlobalStates.barPopupEphemeral = false;
        GlobalStates.barPopupType = "";
        GlobalStates.barPopupAnchorScreen = "";
    }

    function openDialog(dialogType) {
        root.close();
        ActionManager.invoke("settings.open", {section: dialogType});
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
        visible: root.open && root.activeType !== "voiceModel" && root.activeType !== "voice" && root.popupScreen
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
            top: barOnBottom ? 0 : BarPopupGeometry.windowTopMargin
            bottom: barOnBottom ? BarPopupGeometry.windowTopMargin : 0
            right: BarPopupGeometry.rightGap
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
                popupFlick.contentY = 0;
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
            anchors {
                top: parent.top
                right: parent.right
            }
            readonly property real shadowMargin: Appearance.sizes.elevationMargin
            readonly property real maxContentHeight: (popupWindow.screen?.height ?? 1080) * 0.75
            readonly property real calcHeight: Math.min(panelContent.implicitHeight + shadowMargin * 2, maxContentHeight)
            implicitWidth: panelBg.implicitWidth + shadowMargin * 2
            implicitHeight: calcHeight
            width: implicitWidth
            height: calcHeight

            StyledRectangularShadow {
                target: panelBg
                visible: true
            }

            TuiShell {
                id: panelBg
                anchors.fill: parent
                anchors.margins: panel.shadowMargin
                implicitWidth: popupWindow.panelWidth
                implicitHeight: panelContent.implicitHeight
                contentPadding: 0
                useLayerMask: false
                color: TuiStyle.bg
                border.width: TuiStyle.borderWidth
                border.color: TuiStyle.menuBorder
                clip: true
                StyledFlickable {
                    id: popupFlick
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: panelContent.implicitHeight
                    interactive: root.activeType !== "notifications"
                    clip: true

                    ColumnLayout {
                        id: panelContent
                        width: parent.width
                        spacing: 0

                        // Module popup sections — shown when root.activeType matches the popup section type
                        Repeater {
                            model: ModuleLoader.popupSections
                            delegate: Loader {
                                required property var modelData
                                readonly property bool isCurrent: root.activeType === modelData.type
                                active: isCurrent
                                visible: isCurrent
                                source: isCurrent ? modelData.component : ""
                                Layout.fillWidth: true
                                Layout.preferredHeight: isCurrent ? -1 : 0
                                Layout.alignment: Qt.AlignTop
                                onStatusChanged: if (status === Loader.Error) {
                                    console.warn("[Module] Popup section load failed:", modelData.component)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Session action confirmation dialog ──────────────────────────────
    PanelWindow {
        id: confirmWindow
        screen: root.popupScreen
        visible: GlobalStates.sessionConfirmOpen && root.popupScreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:sessionConfirm"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        anchors { top: true; left: true; right: true; bottom: true }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.58)
        }

        Item {
            anchors.fill: parent

            MouseArea {
                anchors.fill: parent
                onClicked: GlobalStates.closeSessionConfirm()
            }

            Rectangle {
                id: confirmDialog
                width: Math.min(parent.width - 96, 560)
                implicitHeight: confirmContent.implicitHeight + 48
                anchors.centerIn: parent
                radius: TuiStyle.shellRadius
                color: TuiStyle.bg
                border.width: TuiStyle.borderWidth
                border.color: TuiStyle.shellBorder
                clip: true

                ColumnLayout {
                    id: confirmContent
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 18

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        Rectangle {
                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 46
                            radius: 23
                            color: TuiStyle.accentWash(TuiStyle.danger)
                            border.width: TuiStyle.borderWidth
                            border.color: TuiStyle.shellBorder

                            NerdIcon {
                                anchors.centerIn: parent
                                text: {
                                    const a = GlobalStates.sessionConfirmAction;
                                    if (a === "logout") return NerdIconMap.logout;
                                    if (a === "reboot") return NerdIconMap.restart;
                                    if (a === "poweroff") return NerdIconMap.powerSettingsNew;
                                    return NerdIconMap.warning;
                                }
                                iconSize: 22
                                color: TuiStyle.fg
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            StyledText {
                                Layout.fillWidth: true
                                text: {
                                    const a = GlobalStates.sessionConfirmAction;
                                    const label = GlobalStates.sessionConfirmLabel || a;
                                    if (a === "logout") return "Log out of this session?";
                                    if (a === "reboot") return "Restart this computer?";
                                    if (a === "poweroff") return "Shut down this computer?";
                                    return `Confirm ${label}`;
                                }
                                color: TuiStyle.fg
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: {
                                    const a = GlobalStates.sessionConfirmAction;
                                    if (a === "logout")
                                        return "Open applications will be closed and the current Hyprland session will end.";
                                    if (a === "reboot")
                                        return "The system will restart after running the selected session action.";
                                    if (a === "poweroff")
                                        return "The system will power off after running the selected session action.";
                                    return "This system action will run immediately after confirmation.";
                                }
                                color: TuiStyle.muted
                                font.pixelSize: Appearance.font.pixelSize.small
                                wrapMode: Text.Wrap
                            }
                        }
                    }

                    // ── Save session checkbox ───────────────────
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: saveSessionRow.implicitHeight
                        Layout.topMargin: 2
                        visible: GlobalStates.sessionConfirmAction === "logout"
                            || GlobalStates.sessionConfirmAction === "reboot"
                            || GlobalStates.sessionConfirmAction === "poweroff"

                        MouseArea {
                            id: sessionCheckHitArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sessionSaveCbx.checked = !sessionSaveCbx.checked
                        }

                        RowLayout {
                            id: saveSessionRow
                            anchors.fill: parent
                            spacing: 12

                            Rectangle {
                                id: sessionSaveCbx
                                property bool checked: true
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                radius: 5
                                color: checked ? TuiStyle.accentWash(TuiStyle.accent) : TuiStyle.surfaceSubtle
                                border.width: TuiStyle.borderWidth
                                border.color: checked ? TuiStyle.accent : TuiStyle.line

                                NerdIcon {
                                    anchors.centerIn: parent
                                    text: NerdIconMap.check
                                    iconSize: 14
                                    color: TuiStyle.fg
                                    visible: sessionSaveCbx.checked
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                StyledText {
                                    Layout.fillWidth: true
                                    text: "Save current session"
                                    color: TuiStyle.fg
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Medium
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: "Automatically restore workspaces and windows on next startup."
                                    color: TuiStyle.muted
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: TuiStyle.line
                        opacity: TuiStyle.dividerOpacity
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 12

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44

                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: cancelMouse.containsMouse ? TuiStyle.controlHover : "transparent"
                                border.width: 1
                                border.color: TuiStyle.panelAlt

                                StyledText {
                                    anchors.centerIn: parent
                                    text: "CANCEL"
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    color: TuiStyle.fg
                                }
                            }

                            MouseArea {
                                id: cancelMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: GlobalStates.closeSessionConfirm()
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44

                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: confirmMouse.containsMouse ? TuiStyle.controlHover : TuiStyle.danger
                                border.width: 1
                                border.color: TuiStyle.panelAlt

                                StyledText {
                                    anchors.centerIn: parent
                                    text: {
                                        const a = GlobalStates.sessionConfirmAction;
                                        if (a === "logout") return "LOG OUT";
                                        if (a === "reboot") return "RESTART";
                                        if (a === "poweroff") return "SHUT DOWN";
                                        return "CONFIRM";
                                    }
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    color: TuiStyle.bg
                                }
                            }

                            MouseArea {
                                id: confirmMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const a = GlobalStates.sessionConfirmAction
                                    const sc = sessionSaveCbx.checked
                                    GlobalStates.closeSessionConfirm()
                                    if (a === "logout") {
                                        Session.logout(sc);
                                    } else if (a === "reboot") {
                                        Session.reboot(sc);
                                    } else if (a === "poweroff") {
                                        Session.poweroff(sc);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                GlobalStates.closeSessionConfirm()
                event.accepted = true
            }
        }
    }

}
