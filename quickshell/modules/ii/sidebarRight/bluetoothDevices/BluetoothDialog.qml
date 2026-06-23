import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

WindowDialog {
    id: root
    backgroundWidth: Math.min(560, Math.max(320, width - 32))
    backgroundHeight: Math.min(620, Math.max(420, height - 96))
    anchorPosition: 0

    onVisibleChanged: {
        if (visible) {
            root.forceActiveFocus();
        }
    }

    WindowDialogTitle {
        text: Translation.tr("Bluetooth")
        textAlignment: Text.AlignHCenter
    }

    WindowDialogSeparator {
        visible: !(Bluetooth.defaultAdapter?.discovering ?? false)
    }
    StyledIndeterminateProgressBar {
        visible: Bluetooth.defaultAdapter?.discovering ?? false
        Layout.fillWidth: true
        Layout.topMargin: 0
        Layout.bottomMargin: 0
        Layout.leftMargin: 0
        Layout.rightMargin: 0
    }
    StyledListView {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.topMargin: 0
        Layout.bottomMargin: 0
        Layout.leftMargin: 0
        Layout.rightMargin: 0

        clip: true
        spacing: 0
        animateAppearance: false

        model: ScriptModel {
            values: BluetoothStatus.friendlyDeviceList
        }
        delegate: BluetoothDeviceItem {
            required property BluetoothDevice modelData
            device: modelData
            anchors {
                left: parent?.left
                right: parent?.right
            }
        }
    }
    WindowDialogSeparator {}

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        spacing: 6

        RippleButton {
            implicitHeight: 28
            implicitWidth: 28
            buttonRadius: 14
            colBackgroundHover: Appearance.tiling.bgHover
            colRipple: Appearance.tiling.bgActive
            onClicked: {
                Quickshell.execDetached(["bash", "-c", `${Config.options.apps.bluetooth}`]);
                GlobalStates.sidebarRightOpen = false;
            }
            MaterialSymbol {
                anchors.centerIn: parent
                text: "settings"
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.tiling.text
            }
        }

        Item { Layout.fillWidth: true }

        RippleButton {
            implicitHeight: 28
            implicitWidth: 28
            buttonRadius: 14
            colBackgroundHover: Appearance.tiling.bgHover
            colRipple: Appearance.tiling.bgActive
            onClicked: root.dismiss()
            MaterialSymbol {
                anchors.centerIn: parent
                text: "check"
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.tiling.text
            }
        }
    }
}
