import qs
import qs.services
import qs.services.network
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

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
        text: Translation.tr("Wi-Fi")
        textAlignment: Text.AlignHCenter
    }

    WindowDialogSeparator {
        visible: !Network.wifiScanning
    }
    StyledIndeterminateProgressBar {
        visible: Network.wifiScanning
        Layout.fillWidth: true
        Layout.topMargin: 0
        Layout.bottomMargin: 0
        Layout.leftMargin: 0
        Layout.rightMargin: 0
    }
    ListView {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.topMargin: 0
        Layout.bottomMargin: 0
        Layout.leftMargin: 0
        Layout.rightMargin: 0

        clip: true
        spacing: 0

        model: ScriptModel {
            values: Network.friendlyWifiNetworks
        }
        delegate: WifiNetworkItem {
            required property WifiAccessPoint modelData
            wifiNetwork: modelData
            width: ListView.view.width
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
                Quickshell.execDetached(["bash", "-c", `${Network.ethernet ? Config.options.apps.networkEthernet : Config.options.apps.network}`]);
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
