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
        colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
        colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
        colRipple: ColorUtils.transparentize(Appearance.colors.colLayer1Active, 1)
        colBackgroundToggled: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 1)
        colBackgroundToggledHover: ColorUtils.transparentize(Appearance.colors.colSecondaryContainerHover, 1)
        colRippleToggled: ColorUtils.transparentize(Appearance.colors.colSecondaryContainerActive, 1)
        toggled: GlobalStates.barPopupType === iconButton.popupType

        onPressed: {
            GlobalStates.barPopupType = GlobalStates.barPopupType === iconButton.popupType
                ? ""
                : iconButton.popupType;
        }
    }

    RowLayout {
        id: indicatorsRowLayout
        anchors.centerIn: parent
        spacing: Config.options.bar.rightModuleSpacing

        Revealer {
            reveal: Audio.sink?.audio?.muted ?? false
            Layout.fillHeight: true
            IconSlot {
                BarNerdIcon {
                    anchors.centerIn: parent
                    text: NerdIconMap.volumeOff
                    color: container.colText
                }
            }
        }

        IconSlot {
            visible: xkbIndicator.active
            implicitWidth: visible ? Config.options.bar.rightIconSlotWidth : 0
            HyprlandXkbIndicator {
                id: xkbIndicator
                anchors.centerIn: parent
                color: container.colText
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

    BatteryHoverPopup {
        id: batteryHoverPopup
        hoverTarget: powerButton
    }
}