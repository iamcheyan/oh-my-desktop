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
    property bool hovered: bluetoothButton.hovered

    readonly property string tuiLauncher: `${FileUtils.trimFileProtocol(Directories.config)}/omd/scripts/launch-tui-tool`

    RippleButton {
        id: bluetoothButton
        anchors.centerIn: parent
        width: Config.options.bar.rightIconSlotWidth
        height: Config.options.bar.rightIconSlotWidth
        buttonRadius: Appearance.rounding.full
        colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
        colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
        colRipple: ColorUtils.transparentize(Appearance.colors.colLayer1Active, 1)

        onClicked: {
            GlobalStates.barDialogType = "bluetooth";
            GlobalStates.barDialogOpen = true;
        }

        onHoveredChanged: {
            if (bluetoothButton.hovered)
                btPopupLoader.open();
            else
                btPopupLoader.close();
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onPressed: (event) => {
            if (event.button === Qt.RightButton) {
                bluetoothMenu.open();
            }
        }
    }

    CosmicIcon {
        anchors.centerIn: bluetoothButton
        name: BluetoothStatus.connected ? "status/bluetooth-active-symbolic" : BluetoothStatus.enabled ? "devices/bluetooth-symbolic" : "status/bluetooth-disabled-symbolic"
        iconSize: Config.options.bar.rightIconSize
        color: Appearance.colors.colBarText
    }

    Loader {
        id: bluetoothMenu
        function open() {
            bluetoothMenu.active = true;
        }
        active: false
        sourceComponent: BluetoothContextMenu {
            Component.onCompleted: this.open();
            anchor {
                window: bluetoothButton.QsWindow.window
                item: bluetoothButton
                gravity: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
                edges: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
            }
            onMenuClosed: {
                bluetoothMenu.active = false;
            }
        }
    }

    Loader {
        id: btPopupLoader
        active: false

        function open() {
            btPopupTimer.stop();
            btPopupLoader.active = true;
        }

        function close() {
            btPopupTimer.restart();
        }

        Timer {
            id: btPopupTimer
            interval: 300
            repeat: false
            onTriggered: btPopupLoader.active = false
        }

        sourceComponent: BluetoothInfoPopup {
            Component.onCompleted: this.visible = true
            anchor {
                window: root.QsWindow.window
                item: root.parent?.parent ?? root
                gravity: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
                edges: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
            }
            onMenuClosed: {
                btPopupLoader.active = false;
            }
        }
    }
}
