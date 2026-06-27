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
        id: root
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        Layout.fillHeight: true
        implicitWidth: Config.options.bar.rightIconSlotWidth
        implicitHeight: Config.options.bar.rightIconSlotWidth
        property bool hovered: wifiButton.hovered

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
            GlobalStates.barPopupType = GlobalStates.barPopupType === "wifi" ? "" : "wifi";
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
