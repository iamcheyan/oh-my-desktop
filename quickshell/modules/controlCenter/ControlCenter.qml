import qs
import qs.services
import qs.modules.common
import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property int sidebarWidth: Appearance.sizes.sidebarWidth

    PanelWindow {
        id: panelWindow
        visible: GlobalStates.controlCenterOpen

        function hide() {
            GlobalStates.controlCenterOpen = false;
        }

        exclusiveZone: 0
        implicitWidth: screen?.width ?? sidebarWidth
        implicitHeight: screen?.height ?? 720
        WlrLayershell.namespace: "quickshell:controlCenter"
        WlrLayershell.keyboardFocus: GlobalStates.controlCenterOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        onVisibleChanged: {
            if (visible) {
                GlobalFocusGrab.addDismissable(panelWindow);
            } else {
                GlobalFocusGrab.removeDismissable(panelWindow);
            }
        }
        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                panelWindow.hide();
            }
        }

        Loader {
            id: sidebarContentLoader
            active: GlobalStates.controlCenterOpen || Config?.options.sidebar.keepRightSidebarLoaded
            anchors.centerIn: parent
            width: Math.min(980, Math.max(760, parent.width - Appearance.sizes.hyprlandGapsOut * 8))
            height: Math.min(parent.height - Appearance.sizes.hyprlandGapsOut * 2, sidebarContentLoader.item?.implicitHeight ?? 300)

            focus: GlobalStates.controlCenterOpen
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
                    panelWindow.hide();
                }
            }

            sourceComponent: ControlCenterContent {}
        }
    }

    IpcHandler {
        target: "controlCenter"

        function toggle(): void {
            GlobalStates.controlCenterOpen = !GlobalStates.controlCenterOpen;
        }

        function close(): void {
            GlobalStates.controlCenterOpen = false;
        }

        function open(): void {
            GlobalStates.controlCenterOpen = true;
        }
    }

    GlobalShortcut {
        name: "controlCenterToggle"
        description: "Toggles right sidebar on press"

        onPressed: {
            GlobalStates.controlCenterOpen = !GlobalStates.controlCenterOpen;
        }
    }
    GlobalShortcut {
        name: "controlCenterOpen"
        description: "Opens right sidebar on press"

        onPressed: {
            GlobalStates.controlCenterOpen = true;
        }
    }
    GlobalShortcut {
        name: "controlCenterClose"
        description: "Closes right sidebar on press"

        onPressed: {
            GlobalStates.controlCenterOpen = false;
        }
    }
}
