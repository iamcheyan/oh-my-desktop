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
    buttonRadius: 0
    colBackground: "#06110e"
    colBackgroundHover: "#091814"
    colRipple: "#174339"
    colBackgroundToggled: "#36ff8b"
    colBackgroundToggledHover: "#36ff8b"
    colRippleToggled: "#36ff8b"
    
    contentItem: StyledText {
        anchors.fill: parent
        text: day
        horizontalAlignment: Text.AlignHCenter
        font.family: Appearance.font.family.monospace
        font.weight: bold ? Font.DemiBold : Font.Normal
        color: (isToday == 1) ? "#030806" : 
            (isToday == 0) ? "#e8fff3" : 
            "#65736e"

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }
}

