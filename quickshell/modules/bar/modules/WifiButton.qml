import Quickshell
import qs.modules.bar
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

Item {
    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.fillHeight: true
    implicitWidth: Config.options.bar.rightIconSlotWidth
    implicitHeight: Config.options.bar.rightIconSlotWidth
    property bool hovered: wifiButton.hovered

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

    RippleButton {
        id: wifiButton
        anchors.centerIn: parent
        width: Config.options.bar.rightIconSlotWidth
        height: Config.options.bar.rightIconSlotWidth
        buttonRadius: Appearance.rounding.full
        colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
        colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
        colRipple: ColorUtils.transparentize(Appearance.colors.colLayer1Active, 1)

        onClicked: {
            GlobalStates.barDialogType = "wifi";
            GlobalStates.barDialogOpen = true;
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onPressed: (event) => {
            if (event.button === Qt.RightButton) {
                wifiMenu.open();
            }
        }
    }

    CosmicIcon {
        anchors.centerIn: wifiButton
        name: Network.cosmicIcon
        iconSize: Config.options.bar.rightIconSize
        color: Appearance.colors.colBarText
    }

    PopupToolTip {
        text: tooltipText
        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
    }

    Loader {
        id: wifiMenu
        function open() {
            wifiMenu.active = true;
        }
        active: false
        sourceComponent: WifiContextMenu {
            Component.onCompleted: this.open();
            anchor {
                window: wifiButton.QsWindow.window
                item: wifiButton
                gravity: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
                edges: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
            }
            onMenuClosed: {
                wifiMenu.active = false;
            }
        }
    }
}
