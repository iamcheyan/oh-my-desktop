import qs.modules.bar
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

Item {
    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.fillHeight: true
    implicitWidth: screenshotButton.implicitWidth
    implicitHeight: screenshotButton.implicitHeight
    property bool hovered: screenshotButton.hovered

    RippleButton {
        id: screenshotButton
        anchors.centerIn: parent
        buttonRadius: Appearance.rounding.full
        colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
        colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
        colRipple: ColorUtils.transparentize(Appearance.colors.colLayer1Active, 1)

        onClicked: {
            Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "screenshot"]);
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onPressed: (event) => {
            if (event.button === Qt.RightButton) {
                screenshotMenu.open();
            }
        }
    }

    CosmicIcon {
        anchors.centerIn: screenshotButton
        name: "apps/accessories-screenshot-symbolic"
        iconSize: Appearance.font.pixelSize.larger + 1
        color: Appearance.colors.colBarText
    }

    PopupToolTip {
        text: Translation.tr("Screenshot tool")
        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
    }

    Loader {
        id: screenshotMenu
        function open() {
            screenshotMenu.active = true;
        }
        active: false
        sourceComponent: ScreenshotContextMenu {
            Component.onCompleted: this.open();
            anchor {
                window: screenshotButton.QsWindow.window
                item: screenshotButton
                gravity: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
                edges: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
            }
            onMenuClosed: {
                screenshotMenu.active = false;
            }
        }
    }
}
