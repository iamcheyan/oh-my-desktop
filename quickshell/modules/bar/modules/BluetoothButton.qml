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
            GlobalStates.barPopupType = "";
            GlobalStates.barDialogType = "bluetooth";
            GlobalStates.barDialogOpen = true;
        }
    }

    NerdIcon {
        anchors.centerIn: bluetoothButton
        text: BluetoothStatus.connected ? NerdIconMap.bluetoothConnected : BluetoothStatus.enabled ? NerdIconMap.bluetooth : NerdIconMap.bluetoothDisabled
        iconSize: Config.options.bar.rightIconSize
        color: Appearance.colors.colBarText
    }

    // Transparent MouseArea for hover detection (non-blocking for clicks)
    MouseArea {
        id: hoverArea
        anchors.fill: bluetoothButton
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    BluetoothHoverPopup {
        id: bluetoothHoverPopup
        hoverTarget: hoverArea
    }
}
