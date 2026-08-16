pragma ComponentBehavior: Bound
import qs
import qs.services
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
        implicitWidth: Appearance.sizes.rightIconSlotSize
        implicitHeight: Appearance.sizes.rightIconSlotSize
        Item {
            id: slotContent
            anchors.centerIn: parent
        }
    }

    component BarIconButton: RippleButton {
        id: iconButton
        property string popupType: ""
        Layout.preferredWidth: Appearance.sizes.rightIconSlotSize
        Layout.preferredHeight: Appearance.sizes.rightIconSlotSize
        buttonRadius: Appearance.sizes.rightIconSlotSize / 2
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

    Component {
        id: hoverComponent
        HoverInfo {}
    }

    Component.onCompleted: HoverInfoService.register("power-indicator", hoverComponent)
    Component.onDestruction: HoverInfoService.unregister("power-indicator")

    RowLayout {
        id: indicatorsRowLayout
        anchors.centerIn: parent
        spacing: Config.options.bar.rightModuleSpacing


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
            altAction: function(event) {
                powerContextMenuLoader.open();
            }
        }
    }

    // Hover info — outside the layout to avoid affecting RowLayout sizing
    HoverInfoPopup {
        id: powerHoverPopup
        moduleId: "power-indicator"
        hoverTarget: powerButton
    }

    BarContextMenu {
        id: powerContextMenuLoader
        anchorItem: powerButton
        sourceComponent: PowerContextMenu {}
    }
}
