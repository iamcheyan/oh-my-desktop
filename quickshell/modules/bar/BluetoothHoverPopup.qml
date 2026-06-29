import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    StyledPopupContent {
        // 1. Status row (Enabled / Disabled)
        StyledPopupValueRow {
            icon: BluetoothStatus.enabled ? "devices/bluetooth-symbolic" : "status/bluetooth-disabled-symbolic"
            label: Translation.tr("Bluetooth:")
            value: BluetoothStatus.enabled ? Translation.tr("Enabled") : Translation.tr("Disabled")
        }

        // 2. Connected Device details (if any)
        StyledPopupValueRow {
            visible: BluetoothStatus.enabled && BluetoothStatus.connected
            icon: "status/bluetooth-active-symbolic"
            label: Translation.tr("Connected Device:")
            value: {
                if (BluetoothStatus.connectedDevices.length > 0) {
                    return BluetoothStatus.connectedDevices[0].name;
                }
                return "";
            }
        }

        // 3. Active count
        StyledPopupValueRow {
            visible: BluetoothStatus.enabled && BluetoothStatus.activeDeviceCount > 1
            icon: "status/bluetooth-active-symbolic"
            label: Translation.tr("Total Devices:")
            value: `${BluetoothStatus.activeDeviceCount}`
        }
    }
}
