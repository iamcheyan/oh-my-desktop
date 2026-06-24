import Quickshell
import qs.modules.bar
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

CircleUtilButton {
    readonly property string tuiLauncher: `${FileUtils.trimFileProtocol(Directories.config)}/omd/scripts/launch-tui-tool`
    readonly property string tooltipText: {
        if (!BluetoothStatus.available)
            return Translation.tr("Bluetooth unavailable");
        if (!BluetoothStatus.enabled)
            return Translation.tr("Bluetooth disabled");
        if (!BluetoothStatus.connected)
            return Translation.tr("Bluetooth not connected");

        const devices = BluetoothStatus.connectedDevices.map(device => {
            const name = device?.name || Translation.tr("Unknown device");
            if (!device?.batteryAvailable)
                return name;
            return `${name} • ${Math.round(device.battery * 100)}%`;
        });

        return devices.join(", ");
    }

    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.fillHeight: true
    onClicked: {
        Quickshell.execDetached([tuiLauncher, "bluetooth"]);
    }
    Item {
        implicitWidth: 20
        implicitHeight: 20
        property bool hovered: parent.hovered
        CosmicIcon {
            anchors.centerIn: parent
            name: BluetoothStatus.connected ? "status/bluetooth-active-symbolic" : BluetoothStatus.enabled ? "devices/bluetooth-symbolic" : "status/bluetooth-disabled-symbolic"
            iconSize: Config.options.bar.rightIconSize
            color: Appearance.colors.colBarText
        }
        PopupToolTip {
            text: tooltipText
            anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
        }
    }
}
