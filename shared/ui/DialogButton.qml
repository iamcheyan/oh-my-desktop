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

    property color colText: TuiStyle.fg
    rippleEnabled: false

    colBackground: ColorUtils.transparentize(TuiStyle.bg, 1)
    colBackgroundHover: "#333333"
    colRipple: "#333333"

    contentItem: StyledText {
        id: buttonTextWidget
        anchors.fill: parent
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        text: buttonText
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Appearance.font.pixelSize.small
        color: root.enabled ? root.colText : TuiStyle.dim

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }
}