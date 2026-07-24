pragma ComponentBehavior: Bound

import qs
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.common
import qs.services

Scope {
    id: root

    function dismiss() {
        if (BarRuntime.screenshotActive) return;
        if (GlobalStates.barPopupType !== "") {
            GlobalStates.barPopupDismissedAt = Date.now();
            GlobalStates.barPopupType = "";
        }
        GlobalFocusGrab.dismiss();
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dismissWindow
            required property ShellScreen modelData

            screen: modelData
            visible: ((BarRuntime.dismissLayerActive ?? false) || GlobalStates.voicePopupOpen)
                && !(BarRuntime.screenshotActive ?? false)
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:bar-dismiss"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            readonly property bool barOnBottom: Config.options.bar.bottom
            readonly property int barGap: Appearance.sizes.barHeight

            anchors {
                top: !barOnBottom
                bottom: barOnBottom
                left: true
                right: true
            }
            // Gap on the bar side lets clicks reach bar buttons for toggle
            // (click again to close). Zero gap when a non-barPopup overlay
            // (e.g. voice model status) is open — any outside click closes it.
            margins {
                top: (!barOnBottom && !GlobalStates.voicePopupOpen) ? barGap : 0
                bottom: (barOnBottom && !GlobalStates.voicePopupOpen) ? barGap : 0
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onPressed: event => {
                    event.accepted = true;
                    root.dismiss();
                }
            }
        }
    }
}
