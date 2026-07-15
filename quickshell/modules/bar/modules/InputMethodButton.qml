import qs
import qs.services
import qs.services as Services
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
        id: button
        anchors.centerIn: parent
        width: Config.options.bar.rightIconSlotWidth
        height: Config.options.bar.rightIconSlotWidth
        buttonRadius: Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: "#18ffffff"
        colBackgroundToggled: "#30ffffff"
        colBackgroundToggledHover: "#40ffffff"
        colRipple: "transparent"
        colRippleToggled: "transparent"
        toggled: GlobalStates.barPopupType === "inputMethod"

        onClicked: {
            if (Date.now() - GlobalStates.barPopupDismissedAt < 200)
                return;
            Services.InputMethod.refresh();
            GlobalStates.barPopupType = GlobalStates.barPopupType === "inputMethod"
                ? ""
                : "inputMethod";
        }

        BarNerdIcon {
            anchors.centerIn: parent
            text: NerdIconMap.keyboard
            color: Appearance.colors.colBarText
        }

        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 1
            anchors.bottomMargin: 1
            width: 13
            height: 13
            radius: 3
            color: TuiStyle.bg

            StyledText {
                anchors.centerIn: parent
                text: Services.InputMethod.badge || "?"
                color: TuiStyle.accent
                font.family: Appearance.font.family.main
                font.pixelSize: 9
                font.weight: Font.DemiBold
            }
        }
    }
}
