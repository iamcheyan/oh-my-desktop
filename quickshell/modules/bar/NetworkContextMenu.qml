pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

BarContextMenu {
    id: root
    menuName: "network"

    function openSettings(type) {
        GlobalStates.barPopupType = "";
        GlobalStates.barDialogType = type;
        GlobalStates.barDialogOpen = true;
        root.close();
    }

    BarContextMenuItem {
        iconName: NerdIconMap.wifi
        label: Translation.tr("Wi-Fi Settings")
        releaseAction: () => root.openSettings("wifi")
    }

    BarContextMenuItem {
        iconName: BluetoothStatus.connected ? NerdIconMap.bluetoothConnected
            : BluetoothStatus.enabled ? NerdIconMap.bluetooth
            : NerdIconMap.bluetoothDisabled
        label: Translation.tr("Bluetooth Settings")
        releaseAction: () => root.openSettings("bluetooth")
    }
}