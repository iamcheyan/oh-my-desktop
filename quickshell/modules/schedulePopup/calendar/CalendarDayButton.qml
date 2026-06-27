import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: button
    property string day
    property int isToday
    property bool bold

    Layout.fillWidth: false
    Layout.fillHeight: false
    implicitWidth: 38; 
    implicitHeight: 38;

    toggled: (isToday == 1)
    buttonRadius: TuiStyle.radius
    colBackground: TuiStyle.panel
    colBackgroundHover: TuiStyle.panelAlt
    colRipple: TuiStyle.line
    colBackgroundToggled: TuiStyle.green
    colBackgroundToggledHover: TuiStyle.green
    colRippleToggled: TuiStyle.green
    
    contentItem: StyledText {
        anchors.fill: parent
        text: day
        horizontalAlignment: Text.AlignHCenter
        font.family: Appearance.font.family.monospace
        font.weight: bold ? Font.DemiBold : Font.Normal
        color: (isToday == 1) ? TuiStyle.bg :
            (isToday == 0) ? TuiStyle.fg :
            TuiStyle.dim

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }
}
