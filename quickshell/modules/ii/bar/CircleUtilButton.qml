import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick

RippleButton {
    id: button

    required default property Item content
    property bool extraActiveCondition: false

    padding: 0
    implicitHeight: Math.max(content.implicitHeight, 20)
    implicitWidth: Math.max(content.implicitWidth, 20)
    contentItem: content

    colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
    colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
    colRipple: ColorUtils.transparentize(Appearance.colors.colLayer1Active, 1)
    colBackgroundToggled: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 1)
    colBackgroundToggledHover: ColorUtils.transparentize(Appearance.colors.colSecondaryContainerHover, 1)
    colRippleToggled: ColorUtils.transparentize(Appearance.colors.colSecondaryContainerActive, 1)
}
