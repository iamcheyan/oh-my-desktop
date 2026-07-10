import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: button
    property string day
    property int isToday
    property bool bold
    property bool compact: false

    Layout.fillWidth: false
    Layout.fillHeight: false
    implicitWidth: compact ? 32 : 38
    implicitHeight: compact ? 32 : 38

    toggled: isToday === 1
    buttonRadius: compact ? implicitWidth / 2 : TuiStyle.radius
    colBackground: compact
        ? (isToday === -1 ? "transparent" : TuiStyle.surfaceSubtle)
        : TuiStyle.panel
    colBackgroundHover: compact ? TuiStyle.surfaceHover : TuiStyle.panelAlt
    colRipple: TuiStyle.line
    colBackgroundToggled: TuiStyle.accent
    colBackgroundToggledHover: TuiStyle.accent
    colRippleToggled: TuiStyle.accent

    contentItem: StyledText {
        anchors.fill: parent
        text: day
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.family: Appearance.font.family.main
        font.pixelSize: compact
            ? Appearance.font.pixelSize.smaller
            : Appearance.font.pixelSize.small
        font.weight: bold ? Font.DemiBold : Font.Normal
        color: isToday === 1 ? TuiStyle.bg
            : isToday === 0 ? TuiStyle.fg
            : TuiStyle.dim

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }
}