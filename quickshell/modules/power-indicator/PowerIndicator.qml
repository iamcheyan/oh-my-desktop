import qs
import qs.core.runtime
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
        buttonRadius: Config.options.bar.rightIconSlotWidth / 2
        colBackground: "transparent"
        colBackgroundHover: Qt.rgba(1, 1, 1, 0.10)
        colBackgroundToggled: Qt.rgba(1, 1, 1, 0.18)
        colBackgroundToggledHover: Qt.rgba(1, 1, 1, 0.26)
        colRipple: Qt.rgba(1, 1, 1, 0.12)
        colRippleToggled: Qt.rgba(1, 1, 1, 0.18)
        toggled: GlobalStates.barPopupType === iconButton.popupType

        onClicked: {
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
            visible: ServiceManager.power?.battery?.showBarIcon ?? false
            IconSlot {
                anchors.centerIn: parent
                BarBatteryIcon {
                    anchors.centerIn: parent
                    color: container.colText
                    visible: ServiceManager.power?.battery?.available ?? false
                }
                BarNerdIcon {
                    anchors.centerIn: parent
                    text: NerdIconMap.powerSettingsNew
                    color: container.colText
                    visible: !(ServiceManager.power?.battery?.available ?? false)
                }
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                z: 10
                onPressed: event => {
                    if (event.button === Qt.RightButton)
                        powerContextMenuLoader.open();
                }
            }
        }
    }

    Loader {
        id: powerContextMenuLoader
        function open() {
            if (powerContextMenuLoader.item)
                powerContextMenuLoader.item.open();
            else
                powerContextMenuLoader.active = true;
        }
        active: false
        sourceComponent: PowerContextMenu {
            Component.onCompleted: this.open()
            anchor {
                window: powerButton.QsWindow.window
                item: powerButton
                gravity: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
                edges: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
            }
            onMenuClosed: powerContextMenuLoader.active = false
        }
    }
}
