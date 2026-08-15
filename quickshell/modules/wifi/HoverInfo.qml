pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.bar
import QtQuick
import QtQuick.Layouts

Item {
    implicitWidth: Math.min(300, contentLayout.implicitWidth + 16)
    implicitHeight: contentLayout.implicitHeight + 16

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: 8
        spacing: 2

        StyledPopupValueRow {
            icon: ServiceManager.network.ethernet ? NerdIconMap.ethernet : NerdIconMap.wifi
            label: "Connection"
            value: ServiceManager.network.networkName.length > 0
                ? ServiceManager.network.networkName
                : (ServiceManager.network.wifiStatus ?? "Disconnected")
        }
        StyledPopupValueRow {
            icon: NerdIconMap.info
            label: "Type"
            value: ServiceManager.network.connectionKind ?? "-"
            visible: ServiceManager.network.connectionKind?.length > 0 ?? false
        }
        StyledPopupValueRow {
            icon: NerdIconMap.wifi
            label: "Signal"
            value: {
                if (ServiceManager.network.ethernet) return "Wired";
                const strength = ServiceManager.network.active?.strength;
                if (strength === undefined || strength === null) return "-";
                return Math.round(strength) + "%";
            }
            visible: !ServiceManager.network.ethernet
        }
        StyledPopupValueRow {
            icon: NerdIconMap.bluetoothConnected
            label: "Bluetooth"
            value: {
                if (!ServiceManager.bluetooth?.connected) return "Not connected";
                const count = ServiceManager.bluetooth?.activeDeviceCount ?? 0;
                if (count === 0) return "Connected";
                const name = ServiceManager.bluetooth?.firstActiveDevice?.name ?? "";
                return name.length > 0 ? name : (count + " device" + (count > 1 ? "s" : ""));
            }
        }
    }
}
