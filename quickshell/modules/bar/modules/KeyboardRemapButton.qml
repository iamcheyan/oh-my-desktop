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

    readonly property bool needsSetup: KeyboardRemap.state === "setup" || !KeyboardRemap.keydReady

    RippleButton {
        id: keyboardButton
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
        toggled: GlobalStates.barPopupType === "keyboard"

        onClicked: {
            if (Date.now() - GlobalStates.barPopupDismissedAt < 200) return;
            GlobalStates.barPopupType = GlobalStates.barPopupType === "keyboard" ? "" : "keyboard";
        }
    }

    BarNerdIcon {
        id: icon
        anchors.centerIn: keyboardButton
        text: NerdIconMap.keyboard
        color: root.needsSetup ? "#F5C542" : Appearance.colors.colBarText
    }
}
