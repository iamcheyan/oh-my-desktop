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
    colBackground: Appearance.tiling.bg
    colBackgroundHover: Appearance.tiling.bgHover
    colBackgroundActive: Appearance.tiling.bgActive
    colBackgroundToggled: Appearance.tiling.bgTitlebar
    colBackgroundToggledHover: Appearance.tiling.accent
    colBackgroundToggledActive: Appearance.tiling.bgActive
    borderWidth: Appearance.tiling.borderWidth
    borderColor: toggled ? Appearance.tiling.borderFocus : Appearance.tiling.border

    contentItem: MaterialSymbol {
        anchors.centerIn: parent
        iconSize: 22
        fill: toggled ? 1 : 0
        color: toggled ? Appearance.tiling.textBright : Appearance.tiling.textDim
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: buttonIcon

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

}
