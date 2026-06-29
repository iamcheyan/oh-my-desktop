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

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

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

    RippleButton {
        id: button
        anchors.centerIn: parent
        width: indicatorsRowLayout.implicitWidth
        height: indicatorsRowLayout.implicitHeight

        buttonRadius: Appearance.rounding.full
        colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
        colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
        colRipple: ColorUtils.transparentize(Appearance.colors.colLayer1Active, 1)
        colBackgroundToggled: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 1)
        colBackgroundToggledHover: ColorUtils.transparentize(Appearance.colors.colSecondaryContainerHover, 1)
        colRippleToggled: ColorUtils.transparentize(Appearance.colors.colSecondaryContainerActive, 1)
        toggled: GlobalStates.controlCenterOpen

        onPressed: {
            GlobalStates.barPopupType = GlobalStates.barPopupType === "battery" ? "" : "battery";
        }

        RowLayout {
            id: indicatorsRowLayout
            anchors.centerIn: parent
            spacing: Config.options.bar.rightModuleSpacing

            Revealer {
                reveal: Audio.sink?.audio?.muted ?? false
                Layout.fillHeight: true
                IconSlot {
                    NerdIcon {
                        anchors.centerIn: parent
                        text: NerdIconMap.volumeOff
                        iconSize: Config.options.bar.rightIconSize
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
            IconSlot {
                id: batteryIconSlot
                NerdIcon {
                    anchors.centerIn: parent
                    text: {
                        const pct = Battery.percentage;
                        if (Battery.isCharging) {
                            if (pct > 0.9) return NerdIconMap.batteryChargingFull;
                            if (pct > 0.8) return NerdIconMap.batteryCharging90;
                            if (pct > 0.7) return NerdIconMap.batteryCharging80;
                            if (pct > 0.6) return NerdIconMap.batteryCharging70;
                            if (pct > 0.5) return NerdIconMap.batteryCharging60;
                            if (pct > 0.4) return NerdIconMap.batteryCharging50;
                            if (pct > 0.3) return NerdIconMap.batteryCharging40;
                            if (pct > 0.2) return NerdIconMap.batteryCharging30;
                            if (pct > 0.1) return NerdIconMap.batteryCharging20;
                            return NerdIconMap.batteryCharging10;
                        } else {
                            if (pct > 0.9) return NerdIconMap.battery90;
                            if (pct > 0.8) return NerdIconMap.battery80;
                            if (pct > 0.7) return NerdIconMap.battery70;
                            if (pct > 0.6) return NerdIconMap.battery60;
                            if (pct > 0.5) return NerdIconMap.battery50;
                            if (pct > 0.4) return NerdIconMap.battery40;
                            if (pct > 0.3) return NerdIconMap.battery30;
                            if (pct > 0.2) return NerdIconMap.battery20;
                            if (pct > 0.1) return NerdIconMap.battery10;
                            return NerdIconMap.batteryAlert;
                        }
                    }
                    iconSize: Config.options.bar.rightIconSize
                    color: container.colText
                }
            }
        }
    }

    // Transparent MouseArea dedicated for hover detection (does not intercept clicks)
    MouseArea {
        id: hoverArea
        anchors.fill: button
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    BatteryHoverPopup {
        id: batteryHoverPopup
        hoverTarget: hoverArea
    }
}
