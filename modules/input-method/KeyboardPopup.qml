// KeyboardPopup.qml — Keyboard remap status popup (from BarStatusPopup keyboardContent).
import qs
import qs.modules.common
import qs.modules.bar
import qs.core.runtime
import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: popup
    spacing: 0
    width: parent?.width ?? implicitWidth

    function stateLabel() {
        if (KeyboardRemap.state === "setup") return "Setup needed";
        if (!KeyboardRemap.keydReady) return "keyd not running";
        if (KeyboardRemap.selectedDeviceId) return "Ready";
        return "No device";
    }
    function tone() {
        if (stateLabel() === "Ready") return TuiStyle.success;
        if (stateLabel() === "Setup needed" || stateLabel() === "keyd not running") return TuiStyle.danger;
        return TuiStyle.muted;
    }

    PopupHeader {
        Layout.fillWidth: true
        icon: NerdIconMap.keyboard
        title: "Keyboard"
        subtitle: popup.stateLabel()
        tone: popup.tone()
    }

    PopupInfoRow { label: "Device"; value: KeyboardRemap.selectedDeviceId || "--"; valueColor: KeyboardRemap.selectedDeviceId ? TuiStyle.fg : TuiStyle.dim }
    PopupInfoRow { label: "Keyd"; value: KeyboardRemap.keydReady ? "Running" : "Not ready"; valueColor: KeyboardRemap.keydReady ? TuiStyle.success : TuiStyle.danger }
    PopupInfoRow {
        label: "Profile"
        value: KeyboardRemap.selectedProfile?.displayName || "--"
        valueColor: KeyboardRemap.selectedProfile ? TuiStyle.accent : TuiStyle.dim
        showDivider: false
    }

    PopupFooterLink {
        Layout.fillWidth: true
        label: "Keyboard settings\u2026"
        onClicked: { GlobalStates.barPopupType = ""; KeyboardRemap.openSettings(); }
    }
}
