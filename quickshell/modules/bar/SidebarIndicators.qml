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
    toggled: GlobalStates.sidebarRightOpen
    property color colText: Appearance.colors.colBarText

    Behavior on colText {
        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
    }

    onPressed: {
        GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
    }

    RowLayout {
        id: indicatorsRowLayout
        anchors.centerIn: parent
        spacing: Config.options.bar.rightModuleSpacing

        Revealer {
            reveal: Audio.sink?.audio?.muted ?? false
            Layout.fillHeight: true
            CosmicIcon {
                name: "status/audio-volume-muted-symbolic"
                iconSize: Appearance.font.pixelSize.larger
                color: root.colText
            }
        }
        Revealer {
            reveal: Audio.source?.audio?.muted ?? false
            Layout.fillHeight: true
            CosmicIcon {
                name: "status/microphone-sensitivity-muted-symbolic"
                iconSize: Appearance.font.pixelSize.larger
                color: root.colText
            }
        }
        HyprlandXkbIndicator {
            Layout.alignment: Qt.AlignVCenter
            color: root.colText
        }
        Revealer {
            reveal: Notifications.silent || Notifications.unread > 0
            Layout.fillHeight: true
            implicitHeight: reveal ? notificationUnreadCount.implicitHeight : 0
            implicitWidth: reveal ? notificationUnreadCount.implicitWidth : 0
            NotificationUnreadCount {
                id: notificationUnreadCount
                color: root.colText
            }
        }
        CosmicIcon {
            name: "actions/system-shutdown-symbolic"
            iconSize: Appearance.font.pixelSize.larger
            color: root.colText
        }
    }
}
