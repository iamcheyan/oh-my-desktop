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
    readonly property string tooltipText: {
        if (Network.ethernet)
            return Network.networkName.length > 0
                ? Translation.tr("Wired: %1").arg(Network.networkName)
                : Translation.tr("Wired connected");

        if (!Network.wifiEnabled || Network.wifiStatus === "disabled")
            return Translation.tr("Wi-Fi disabled");

        if (Network.wifiStatus === "connected") {
            const name = Network.active?.ssid || Network.networkName || Translation.tr("Connected");
            const strength = Network.active?.strength ?? Network.networkStrength;
            return Number.isFinite(strength)
                ? Translation.tr("%1 • %2%").arg(name).arg(strength)
                : name;
        }

        if (Network.wifiStatus === "connecting")
            return Network.wifiConnectTarget?.ssid
                ? Translation.tr("Connecting to %1").arg(Network.wifiConnectTarget.ssid)
                : Translation.tr("Connecting to Wi-Fi");

        if (Network.wifiStatus === "limited")
            return Network.networkName.length > 0
                ? Translation.tr("%1 • Limited connectivity").arg(Network.networkName)
                : Translation.tr("Limited connectivity");

        return Translation.tr("Wi-Fi not connected");
    }

    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.fillHeight: true
    onClicked: {
        GlobalStates.barDialogType = "wifi";
        GlobalStates.barDialogOpen = true;
    }
    Item {
        implicitWidth: 20
        implicitHeight: 20
        property bool hovered: parent.hovered
        CosmicIcon {
            anchors.centerIn: parent
            name: Network.cosmicIcon
            iconSize: Config.options.bar.rightIconSize
            color: Appearance.colors.colBarText
        }
        PopupToolTip {
            text: tooltipText
            anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
        }
    }
}
