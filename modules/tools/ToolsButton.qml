import qs
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
        buttonRadius: Config.options.bar.rightIconSlotWidth / 2
        colBackground: "transparent"
        colBackgroundHover: Qt.rgba(1, 1, 1, 0.10)
        colBackgroundToggled: Qt.rgba(1, 1, 1, 0.18)
        colBackgroundToggledHover: Qt.rgba(1, 1, 1, 0.26)
        colRipple: Qt.rgba(1, 1, 1, 0.12)
        colRippleToggled: Qt.rgba(1, 1, 1, 0.18)
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
