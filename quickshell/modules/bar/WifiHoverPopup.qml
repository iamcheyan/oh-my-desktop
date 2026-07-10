import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    StyledPopupContent {
        // Wi-Fi
        StyledPopupValueRow {
            icon: Network.nerdIcon
            label: Translation.tr("Internet:")
            value: {
                if (Network.ethernet) return Translation.tr("Connected (Ethernet)");
                if (Network.wifiStatus === "connected") return Translation.tr("Connected (Wi-Fi)");
                if (Network.wifiStatus === "connecting") return Translation.tr("Connecting...");
                if (Network.wifiStatus === "disconnected") return Translation.tr("Disconnected");
                if (Network.wifiStatus === "disabled") return Translation.tr("Disabled");
                return Network.wifiStatus;
            }
        }

        StyledPopupValueRow {
            visible: Network.wifiStatus === "connected" && Network.networkName !== ""
            icon: NerdIconMap.wifi
            label: Translation.tr("SSID:")
            value: Network.networkName
        }

        StyledPopupValueRow {
            visible: Network.wifiStatus === "connected" && !Network.ethernet
            icon: NerdIconMap.wifi
            label: Translation.tr("Signal Strength:")
            value: `${Network.networkStrength}%`
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            implicitHeight: 1
            color: TuiStyle.line
            opacity: TuiStyle.dividerOpacity
            visible: BluetoothStatus.available
        }

        // Bluetooth
        StyledPopupValueRow {
            visible: BluetoothStatus.available
            icon: BluetoothStatus.enabled ? NerdIconMap.bluetooth : NerdIconMap.bluetoothDisabled
            label: Translation.tr("Bluetooth:")
            value: BluetoothStatus.enabled ? Translation.tr("Enabled") : Translation.tr("Disabled")
        }

        StyledPopupValueRow {
            visible: BluetoothStatus.available && BluetoothStatus.enabled && BluetoothStatus.connected
            icon: NerdIconMap.bluetoothConnected
            label: Translation.tr("Connected Device:")
            value: BluetoothStatus.connectedDevices.length > 0
                ? BluetoothStatus.connectedDevices[0].name
                : ""
        }

        StyledPopupValueRow {
            visible: BluetoothStatus.available && BluetoothStatus.enabled && BluetoothStatus.activeDeviceCount > 1
            icon: NerdIconMap.bluetooth
            label: Translation.tr("Total Devices:")
            value: `${BluetoothStatus.activeDeviceCount}`
        }
    }
}