import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick

RippleButton {
    id: button

    required default property Item content
    property bool extraActiveCondition: false
    readonly property int slotSize: Config.options.bar.rightIconSlotWidth

    padding: 0
    implicitHeight: slotSize
    implicitWidth: slotSize
    contentItem: content

    buttonRadius: slotSize / 2

    colBackground: "transparent"
    colBackgroundHover: Qt.rgba(1, 1, 1, 0.10)
    colBackgroundToggled: Qt.rgba(1, 1, 1, 0.18)
    colBackgroundToggledHover: Qt.rgba(1, 1, 1, 0.26)
    colRipple: Qt.rgba(1, 1, 1, 0.12)
    colRippleToggled: Qt.rgba(1, 1, 1, 0.18)
}
