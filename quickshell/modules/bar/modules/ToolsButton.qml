import qs
import qs.modules.bar
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.fillHeight: true
    implicitWidth: Config.options.bar.rightIconSlotWidth
    implicitHeight: Config.options.bar.rightIconSlotWidth

    RippleButton {
        id: toolsButton
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
        toggled: GlobalStates.barPopupType === "tools"

        onClicked: {
            if (Date.now() - GlobalStates.barPopupDismissedAt < 200)
                return;
            GlobalStates.barPopupType = GlobalStates.barPopupType === "tools" ? "" : "tools";
        }
    }

    BarNerdIcon {
        anchors.centerIn: toolsButton
        text: NerdIconMap.wrench
        color: Appearance.colors.colBarText
    }
}
