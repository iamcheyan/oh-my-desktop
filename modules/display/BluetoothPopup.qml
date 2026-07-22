// BluetoothPopup.qml — Bluetooth status popup.
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.bar
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

ColumnLayout {
    id: popup
    spacing: 0
    width: parent?.width ?? implicitWidth

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
