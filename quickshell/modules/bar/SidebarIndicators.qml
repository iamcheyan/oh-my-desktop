import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: container
    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.fillWidth: false
    Layout.fillHeight: true

    implicitWidth: indicatorsRowLayout.implicitWidth
    implicitHeight: indicatorsRowLayout.implicitHeight
    visible: true

    property color colText: Appearance.colors.colBarText

    component IconSlot: Item {
        default property alias contents: slotContent.data

        implicitWidth: Config.options.bar.rightIconSlotWidth
        implicitHeight: Config.options.bar.rightIconSlotWidth

        Item {
            id: slotContent
            anchors.centerIn: parent
        }
    }

    component BarIconButton: RippleButton {
        id: iconButton
        property string popupType: ""

        Layout.preferredWidth: Config.options.bar.rightIconSlotWidth
        Layout.preferredHeight: Config.options.bar.rightIconSlotWidth
        buttonRadius: Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: "#18ffffff"
        colBackgroundToggled: "#30ffffff"
        colBackgroundToggledHover: "#40ffffff"
        colRipple: "transparent"
        colRippleToggled: "transparent"
        toggled: GlobalStates.barPopupType === iconButton.popupType

        onPressed: {
            if (Date.now() - GlobalStates.barPopupDismissedAt < 200) return;
            GlobalStates.barPopupType = GlobalStates.barPopupType === iconButton.popupType
                ? ""
                : iconButton.popupType;
        }
    }

    RowLayout {
        id: indicatorsRowLayout
        anchors.centerIn: parent
        spacing: Config.options.bar.rightModuleSpacing

        BarIconButton {
            id: xkbButton
            popupType: "xkb"
            visible: xkbIndicator.active
            Layout.preferredWidth: visible ? Config.options.bar.rightIconSlotWidth : 0
            Layout.preferredHeight: Config.options.bar.rightIconSlotWidth
            IconSlot {
                anchors.centerIn: parent
                HyprlandXkbIndicator {
                    id: xkbIndicator
                    anchors.centerIn: parent
                    color: container.colText
                }
            }
        }

        BarIconButton {
            id: powerButton
            popupType: "battery"
            visible: Battery.showBarIcon
            IconSlot {
                anchors.centerIn: parent
                BarBatteryIcon {
                    anchors.centerIn: parent
                    color: container.colText
                    visible: Battery.available
                }
                BarNerdIcon {
                    anchors.centerIn: parent
                    text: NerdIconMap.powerSettingsNew
                    color: container.colText
                    visible: !Battery.available
                }
            }
        }
    }
}
