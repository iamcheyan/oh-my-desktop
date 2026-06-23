import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick

RippleButton {
    id: root
    property bool active: false
    property bool selected: false

    horizontalPadding: 10
    verticalPadding: 8

    clip: true
    pointingHandCursor: !active
    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
    implicitHeight: contentItem.implicitHeight + verticalPadding * 2
    Behavior on implicitHeight {
        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
    }

    rippleEnabled: false
    colBackground: root.selected ? Appearance.colors.colSecondaryContainer : ColorUtils.transparentize(Appearance.tiling.bg, 1)
    colBackgroundHover: active ? colBackground : Appearance.tiling.bgHover
    colRipple: Appearance.tiling.bgHover
    buttonRadius: 0
    borderWidth: 0
}