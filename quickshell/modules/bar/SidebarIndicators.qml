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
            GlobalStates.controlCenterOpen = !GlobalStates.controlCenterOpen;
        }

        onHoveredChanged: {
            if (button.hovered)
                batteryPopupLoader.open();
            else
                batteryPopupLoader.close();
        }

        RowLayout {
            id: indicatorsRowLayout
            anchors.centerIn: parent
            spacing: Config.options.bar.rightModuleSpacing

            Revealer {
                reveal: Audio.sink?.audio?.muted ?? false
                Layout.fillHeight: true
                IconSlot {
                    CosmicIcon {
                        anchors.centerIn: parent
                        name: "status/audio-volume-muted-symbolic"
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
                CosmicIcon {
                    anchors.centerIn: parent
                    name: Battery.isCharging ? "status/plugged-into-power-symbolic" : "devices/battery-symbolic"
                    iconSize: Config.options.bar.rightIconSize
                    color: container.colText
                }
            }
        }
    }

    Loader {
        id: batteryPopupLoader
        active: false

        function open() {
            batteryPopupTimer.stop();
            batteryPopupLoader.active = true;
        }

        function close() {
            batteryPopupTimer.restart();
        }

        Timer {
            id: batteryPopupTimer
            interval: 300
            repeat: false
            onTriggered: batteryPopupLoader.active = false
        }

        sourceComponent: BatteryInfoPopup {
            Component.onCompleted: this.visible = true
            anchor {
                window: container.QsWindow.window
                item: container
                gravity: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
                edges: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
            }
            onMenuClosed: {
                batteryPopupLoader.active = false;
            }
        }
    }
}
