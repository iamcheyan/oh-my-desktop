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
        visible: GlobalStates.sidebarRightOpen

        function hide() {
            GlobalStates.sidebarRightOpen = false;
        }

        exclusiveZone: 0
        implicitWidth: screen?.width ?? sidebarWidth
        implicitHeight: screen?.height ?? 720
        WlrLayershell.namespace: "quickshell:sidebarRight"
        WlrLayershell.keyboardFocus: GlobalStates.sidebarRightOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
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
            active: GlobalStates.sidebarRightOpen || Config?.options.sidebar.keepRightSidebarLoaded
            anchors {
                centerIn: parent
            }
            width: Math.min(980, Math.max(760, parent.width - Appearance.sizes.hyprlandGapsOut * 8))
            height: Math.min(700, Math.max(520, parent.height - Appearance.sizes.hyprlandGapsOut * 8))

            focus: GlobalStates.sidebarRightOpen
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
                    panelWindow.hide();
                }
            }

            sourceComponent: SidebarRightContent {}
        }
    }

    IpcHandler {
        target: "sidebarRight"

        function toggle(): void {
            GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
        }

        function close(): void {
            GlobalStates.sidebarRightOpen = false;
        }

        function open(): void {
            GlobalStates.sidebarRightOpen = true;
        }
    }

    GlobalShortcut {
        name: "sidebarRightToggle"
        description: "Toggles right sidebar on press"

        onPressed: {
            GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
        }
    }
    GlobalShortcut {
        name: "sidebarRightOpen"
        description: "Opens right sidebar on press"

        onPressed: {
            GlobalStates.sidebarRightOpen = true;
        }
    }
    GlobalShortcut {
        name: "sidebarRightClose"
        description: "Closes right sidebar on press"

        onPressed: {
            GlobalStates.sidebarRightOpen = false;
        }
    }
}
