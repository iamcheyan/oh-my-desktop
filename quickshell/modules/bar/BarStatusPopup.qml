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
                radius: TuiStyle.shellRadius
                clip: true

                StyledFlickable {
                    id: popupFlick
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: panelContent.implicitHeight
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

        MouseArea {
            anchors.fill: parent
            onClicked: GlobalStates.closeSessionConfirm()
        }

        Rectangle {
            anchors.centerIn: parent
            width: 320
            height: confirmColumn.implicitHeight + 32
            radius: 12
            color: TuiStyle.bg
            border.color: TuiStyle.menuBorder
            border.width: 1

            ColumnLayout {
                id: confirmColumn
                anchors {
                    left: parent.left; right: parent.right
                    top: parent.top; margins: 16
                }
                spacing: 16

                StyledText {
                    Layout.fillWidth: true
                    text: GlobalStates.sessionConfirmLabel
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    color: TuiStyle.fg
                    horizontalAlignment: Qt.AlignHCenter
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

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
                                text: "Cancel"
                                font.pixelSize: 13
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
                            color: confirmMouse.containsMouse ? TuiStyle.controlHover : TuiStyle.accent
                            border.width: 1
                            border.color: TuiStyle.panelAlt

                            StyledText {
                                anchors.centerIn: parent
                                text: "Confirm"
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
                                GlobalStates.closeSessionConfirm()
                                if (a && ActionManager.isAvailable(a))
                                    ActionManager.invoke(a)
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
