import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/**
 * SessionActionButton — circular action button used in the session/power screen.
 *
 * Visual design follows the OMD TuiStyle system:
 *   - Unfocused: dark surface (TuiStyle.surfaceRaised) with 2px accent border
 *     (TuiStyle.shellBorder), TuiStyle.shellRadius rounded corners
 *   - Focused/hovered: accent background (TuiStyle.accent), fully circular,
 *     dark icon (TuiStyle.bg) for contrast
 *   - Pressed: surfacePressed, circular
 *
 * The border matches the rest of shell chrome (menus, dialogs, popups) which
 * all use TuiStyle.borderWidth + TuiStyle.shellBorder.
 */
RippleButton {
    id: button

    property string buttonIcon
    property string buttonText
    property bool keyboardDown: false
    property real size: 110

    // Unfocused: rounded rect (shellRadius). Focused/pressed: circle.
    buttonRadius: (button.focus || button.down) ? size / 2 : TuiStyle.shellRadius

    // Background colors
    colBackground: button.keyboardDown ? TuiStyle.surfacePressed
        : button.focus ? TuiStyle.accent
        : TuiStyle.surfaceRaised
    colBackgroundHover: TuiStyle.accent
    colRipple: TuiStyle.accent

    // Border — 2px accent border, same as menus/dialogs/popups
    borderWidth: TuiStyle.borderWidth
    borderColor: TuiStyle.shellBorder

    // Icon color: dark on accent (focused), bright on dark surface
    property color colText: (button.down || button.keyboardDown || button.focus || button.hovered) ?
        TuiStyle.bg : TuiStyle.fg

    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
    background.implicitHeight: size
    background.implicitWidth: size

    Behavior on buttonRadius {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            keyboardDown = true
            button.clicked()
            event.accepted = true;
        }
    }
    Keys.onReleased: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            keyboardDown = false
            event.accepted = true;
        }
    }

    contentItem: MaterialSymbol {
        id: icon
        anchors.fill: parent
        color: button.colText
        horizontalAlignment: Text.AlignHCenter
        iconSize: 40
        text: buttonIcon
    }

    StyledToolTip {
        text: buttonText
    }
}