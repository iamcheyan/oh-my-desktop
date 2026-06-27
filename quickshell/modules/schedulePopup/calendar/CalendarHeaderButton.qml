import qs.modules.common
import qs.modules.common.widgets
import QtQuick

RippleButton {
    id: button
    property string buttonText: ""
    property string tooltipText: ""
    property bool forceCircle: false

    implicitHeight: 30
    implicitWidth: forceCircle ? implicitHeight : (contentItem.implicitWidth + 10 * 2)
    Behavior on implicitWidth {
        SmoothedAnimation {
            velocity: Appearance.animation.elementMove.velocity
        }
    }

    background.anchors.fill: button
    buttonRadius: 0
    colBackground: "#06110e"
    colBackgroundHover: "#091814"
    colRipple: "#174339"

    contentItem: StyledText {
        text: buttonText
        horizontalAlignment: Text.AlignHCenter
        font.family: Appearance.font.family.monospace
        font.pixelSize: Appearance.font.pixelSize.larger
        color: "#e8fff3"
    }

    StyledToolTip {
        text: tooltipText
        extraVisibleCondition: tooltipText.length > 0
    }
}