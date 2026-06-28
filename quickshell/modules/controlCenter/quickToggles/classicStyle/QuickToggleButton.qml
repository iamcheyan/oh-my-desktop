import qs.modules.common
import qs.modules.common.widgets
import QtQuick

GroupButton {
    id: button
    property string buttonIcon
    baseWidth: 38
    baseHeight: 38
    clickedWidth: baseWidth
    bounce: false
    toggled: false
    buttonRadius: 0
    buttonRadiusPressed: 0
    colBackground: TuiStyle.bg
    colBackgroundHover: "#333333"
    colBackgroundActive: "#222222"
    colBackgroundToggled: "#181818"
    colBackgroundToggledHover: TuiStyle.accent
    colBackgroundToggledActive: "#222222"
    borderWidth: TuiStyle.borderWidth
    borderColor: toggled ? TuiStyle.accent : TuiStyle.line

    contentItem: MaterialSymbol {
        anchors.centerIn: parent
        iconSize: 22
        fill: toggled ? 1 : 0
        color: toggled ? TuiStyle.fg : TuiStyle.dim
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: buttonIcon

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

}
