import qs.modules.common
import qs.modules.common.widgets
import QtQuick

RippleButton {
    id: button
    property string buttonText: ""
    property string tooltipText: ""
    property bool forceCircle: false

    implicitHeight: 28
    implicitWidth: forceCircle ? implicitHeight : (contentItem.implicitWidth + 16 * 2)
    Behavior on implicitWidth {
        SmoothedAnimation {
            velocity: Appearance.animation.elementMove.velocity
        }
    }

    background.anchors.fill: button
    buttonRadius: forceCircle ? implicitHeight / 2 : 8
    colBackground: TuiStyle.surfaceSubtle
    colBackgroundHover: TuiStyle.surfaceHover
    colRipple: TuiStyle.line

    contentItem: StyledText {
        text: buttonText
        horizontalAlignment: Text.AlignHCenter
        font.family: Appearance.font.family.monospace
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.DemiBold
        color: TuiStyle.fg
    }

    StyledToolTip {
        text: tooltipText
        extraVisibleCondition: tooltipText.length > 0
    }
}
