import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        ?? Quickshell.screens[0]
        ?? null

    PanelWindow {
        id: panelWindow
        screen: root.focusedScreen
        visible: GlobalStates.scheduleOpen && !GlobalStates.screenLocked && root.focusedScreen

        readonly property real popupWidth: Math.min(
            Appearance.sizes.sidebarWidth,
            Math.max(320, (panelWindow.screen?.width ?? 1920) - 32)
        )
        readonly property bool barOnBottom: Config.options.bar.bottom

        function hide() {
            GlobalStates.scheduleOpen = false;
        }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.namespace: "quickshell:schedulePopup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: GlobalStates.scheduleOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        anchors {
            top: !barOnBottom
            bottom: barOnBottom
        }

        margins {
            top: barOnBottom ? 0 : Appearance.sizes.barHeight
            bottom: barOnBottom ? Appearance.sizes.barHeight : 0
        }

        implicitWidth: schedulePanel.implicitWidth
        implicitHeight: schedulePanel.implicitHeight

        mask: Region {
            item: schedulePanel
        }

        Timer {
            id: dismissGuard
            interval: 150
            repeat: false
            onTriggered: GlobalFocusGrab.addDismissable(panelWindow)
        }

        onVisibleChanged: {
            if (visible) {
                dismissGuard.restart();
            } else {
                dismissGuard.stop();
                GlobalFocusGrab.removeDismissable(panelWindow);
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                panelWindow.hide();
            }
        }

        Connections {
            target: GlobalStates
            function onScheduleOpenChanged() {
                if (GlobalStates.scheduleOpen)
                    panelWindow.screen = root.focusedScreen;
            }
        }

        Item {
            id: schedulePanel
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: panelWindow.popupWidth
            implicitHeight: scheduleContent.implicitHeight + 8

            StyledRectangularShadow {
                target: scheduleBackground
            }

            Rectangle {
                id: scheduleBackground
                anchors.centerIn: parent
                implicitWidth: panelWindow.popupWidth
                implicitHeight: scheduleContent.implicitHeight + 8
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                radius: Appearance.rounding.normal

                BottomWidgetGroup {
                    id: scheduleContent
                    anchors.fill: parent
                    anchors.margins: 4
                    popupMode: true
                }
            }
        }
    }

    IpcHandler {
        target: "schedule"

        function toggle(): void {
            GlobalStates.scheduleOpen = !GlobalStates.scheduleOpen;
        }

        function close(): void {
            GlobalStates.scheduleOpen = false;
        }

        function open(): void {
            GlobalStates.scheduleOpen = true;
        }
    }
}