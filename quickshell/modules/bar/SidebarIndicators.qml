import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: root

    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.fillWidth: false
    Layout.fillHeight: true

    implicitWidth: indicatorsRowLayout.implicitWidth
    implicitHeight: indicatorsRowLayout.implicitHeight

    buttonRadius: Appearance.rounding.full
    colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
    colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
    colRipple: ColorUtils.transparentize(Appearance.colors.colLayer1Active, 1)
    colBackgroundToggled: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 1)
    colBackgroundToggledHover: ColorUtils.transparentize(Appearance.colors.colSecondaryContainerHover, 1)
    colRippleToggled: ColorUtils.transparentize(Appearance.colors.colSecondaryContainerActive, 1)
    toggled: GlobalStates.controlCenterOpen
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

    Behavior on colText {
        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
    }

    onPressed: {
        GlobalStates.controlCenterOpen = !GlobalStates.controlCenterOpen;
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
                    color: root.colText
                }
            }
        }
        Revealer {
            reveal: Audio.source?.audio?.muted ?? false
            Layout.fillHeight: true
            IconSlot {
                CosmicIcon {
                    anchors.centerIn: parent
                    name: "status/microphone-sensitivity-muted-symbolic"
                    iconSize: Config.options.bar.rightIconSize
                    color: root.colText
                }
            }
        }
        IconSlot {
            visible: xkbIndicator.active
            implicitWidth: visible ? Config.options.bar.rightIconSlotWidth : 0
            HyprlandXkbIndicator {
                id: xkbIndicator
                anchors.centerIn: parent
                color: root.colText
            }
        }
        Revealer {
            reveal: Notifications.silent || Notifications.unread > 0
            Layout.fillHeight: true
            implicitHeight: reveal ? Config.options.bar.rightIconSlotWidth : 0
            implicitWidth: reveal ? Config.options.bar.rightIconSlotWidth : 0
            IconSlot {
                NotificationUnreadCount {
                    id: notificationUnreadCount
                    anchors.centerIn: parent
                    color: root.colText
                }
            }
        }
        IconSlot {
            CosmicIcon {
                anchors.centerIn: parent
                name: "actions/system-shutdown-symbolic"
                iconSize: Config.options.bar.rightIconSize
                color: root.colText
            }
        }
    }
}
