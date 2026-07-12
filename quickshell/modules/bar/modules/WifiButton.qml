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

    RippleButton {
        id: wifiButton
        anchors.centerIn: parent
        width: Config.options.bar.rightIconSlotWidth
        height: Config.options.bar.rightIconSlotWidth
        buttonRadius: Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: "#18ffffff"
        colRipple: "transparent"
        toggled: GlobalStates.barPopupType === "wifi"

        onClicked: {
            if (Date.now() - GlobalStates.barPopupDismissedAt < 200) return;
            GlobalStates.barPopupType = GlobalStates.barPopupType === "wifi" ? "" : "wifi";
        }
    }

    BarNerdIcon {
        anchors.centerIn: wifiButton
        text: Network.nerdIcon
        color: Appearance.colors.colBarText
    }
}
