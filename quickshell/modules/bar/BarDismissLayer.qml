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
            visible: (BarRuntime.dismissLayerActive ?? false)
                && !(BarRuntime.screenshotActive ?? false)
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:bar-dismiss"
            // Keep the catcher in the same layer as BarStatusPopup. The
            // popup is mapped after this persistent window and therefore
            // remains clickable, while every uncovered point is guaranteed
            // to target this surface. A Top-layer transparent surface is not
            // a reliable pointer target on every Hyprland layer-shell path.
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // A transparent PanelWindow does not imply a non-empty input
            // region. Declare it explicitly; otherwise compositor updates
            // can leave the visual full-screen layer click-through.
            mask: Region {
                item: dismissMouse
            }

            readonly property bool barOnBottom: Config.options.bar.bottom
            readonly property int barGap: Appearance.sizes.barHeight

            anchors {
                top: !barOnBottom
                bottom: barOnBottom
                left: true
                right: true
            }
            // Status popups keep a gap on the bar side so their originating
            // button can toggle them closed. A context menu has no matching
            // toggle: the bar is outside it and must therefore close it too.
            margins {
                top: (!barOnBottom && GlobalStates.barPopupType !== ""
                    && GlobalStates.barPopupType !== "voiceModel"
                    && GlobalStates.barPopupType !== "voice") ? barGap : 0
                bottom: (barOnBottom && GlobalStates.barPopupType !== ""
                    && GlobalStates.barPopupType !== "voiceModel"
                    && GlobalStates.barPopupType !== "voice") ? barGap : 0
            }


            MouseArea {
                id: dismissMouse
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onPressed: event => {
                    event.accepted = true;
                    console.log("[BARPOPUP] outside click — dismissing active popup/menu");
                    root.dismiss();
                }
            }
        }
    }
}
