import Quickshell
import Quickshell.Io
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
    property bool hovered: wifiButton.hovered || (networkMenuLoader.item ? networkMenuLoader.item.visible : false)

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
            GlobalStates.barPopupType = "";
            Quickshell.execDetached([`${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-settings`, "open", "wifi"]);
        }
    }

    BarNerdIcon {
        anchors.centerIn: wifiButton
        text: Network.nerdIcon
        color: Appearance.colors.colBarText
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onPressed: event => {
            if (event.button === Qt.RightButton)
                networkMenuLoader.open();
        }
    }

    Loader {
        id: networkMenuLoader
        function open() {
            if (networkMenuLoader.item)
                networkMenuLoader.item.open();
            else
                networkMenuLoader.active = true;
        }
        active: false
        sourceComponent: NetworkContextMenu {
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
            onMenuClosed: networkMenuLoader.active = false
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: wifiButton
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    WifiHoverPopup {
        id: wifiHoverPopup
        hoverTarget: hoverArea
    }
}