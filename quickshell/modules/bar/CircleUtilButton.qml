import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick

RippleButton {
    id: button

    required default property Item content
    property bool extraActiveCondition: false
    readonly property int slotSize: 28

    padding: 0
    implicitHeight: slotSize
    implicitWidth: slotSize
    contentItem: content

    colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
    colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
    colRipple: ColorUtils.transparentize(Appearance.colors.colLayer1Active, 1)
    colBackgroundToggled: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 1)
    colBackgroundToggledHover: ColorUtils.transparentize(Appearance.colors.colSecondaryContainerHover, 1)
    colRippleToggled: ColorUtils.transparentize(Appearance.colors.colSecondaryContainerActive, 1)
}
