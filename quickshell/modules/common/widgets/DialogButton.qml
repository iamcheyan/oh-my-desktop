import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick

RippleButton {
    id: root

    property string buttonText
    padding: 12
    implicitHeight: 30
    implicitWidth: buttonTextWidget.implicitWidth + padding * 2
    buttonRadius: 0

    property color colText: Appearance.tiling.text
    rippleEnabled: false

    colBackground: ColorUtils.transparentize(Appearance.tiling.bg, 1)
    colBackgroundHover: Appearance.tiling.bgHover
    colRipple: Appearance.tiling.bgHover

    contentItem: StyledText {
        id: buttonTextWidget
        anchors.fill: parent
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        text: buttonText
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Appearance.font.pixelSize.small
        color: root.enabled ? root.colText : Appearance.tiling.textDim

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }
}