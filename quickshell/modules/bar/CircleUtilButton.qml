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

    colBackground: "transparent"
    colBackgroundHover: "#18ffffff"
    colRipple: "transparent"
    colBackgroundToggled: "#30ffffff"
    colBackgroundToggledHover: "#40ffffff"
    colRippleToggled: "transparent"
}
