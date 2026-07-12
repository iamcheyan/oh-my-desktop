import qs
import qs.modules.bar
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: root
    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.fillHeight: true
    implicitWidth: Config.options.bar.rightIconSlotWidth
    implicitHeight: Config.options.bar.rightIconSlotWidth

    RippleButton {
        id: sessionButton
        anchors.centerIn: parent
        width: Config.options.bar.rightIconSlotWidth
        height: Config.options.bar.rightIconSlotWidth
        buttonRadius: Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: "#18ffffff"
        colRipple: "transparent"
        colBackgroundToggled: "#30ffffff"
        colBackgroundToggledHover: "#40ffffff"
        colRippleToggled: "transparent"
        toggled: GlobalStates.barPopupType === "session"

        onClicked: {
            if (Date.now() - GlobalStates.barPopupDismissedAt < 200) return;
            GlobalStates.barPopupType = GlobalStates.barPopupType === "session" ? "" : "session";
        }
    }

    BarNerdIcon {
        anchors.centerIn: sessionButton
        text: NerdIconMap.workspaceSnapshot
        color: Appearance.colors.colBarText
    }
}
