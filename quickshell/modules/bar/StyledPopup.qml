import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

LazyLoader {
    id: root

    property Item hoverTarget
    default property Item contentItem
    property real popupBackgroundMargin: 0
    property bool alignRight: false
    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        ?? Quickshell.screens[0]
        ?? null

    active: hoverTarget && hoverTarget.containsMouse && GlobalStates.activeContextMenu === ""

    component: PanelWindow {
        id: popupWindow
        screen: root.focusedScreen
        color: "transparent"

        readonly property bool barOnBottom: Config.options.bar.bottom
        readonly property real visualWidth: popupBackground.implicitWidth + root.popupBackgroundMargin
        readonly property real visualHeight: popupBackground.implicitHeight + root.popupBackgroundMargin
        readonly property real centeredLeft: {
            if (Config.options.bar.vertical)
                return Appearance.sizes.verticalBarWidth;
            const xOffset = root.alignRight
                ? root.hoverTarget.width - popupBackground.implicitWidth
                : (root.hoverTarget.width - popupBackground.implicitWidth) / 2;
            return root.hoverTarget?.mapToItem(null, xOffset, 0).x ?? 4;
        }
        readonly property bool snapRight: !Config.options.bar.vertical
            && centeredLeft + visualWidth > (screen?.width ?? 1920) - 4;

        anchors {
            left: Config.options.bar.vertical
                ? (!Config.options.bar.bottom)
                : !snapRight
            right: Config.options.bar.vertical
                ? Config.options.bar.bottom
                : snapRight
            top: Config.options.bar.vertical || !barOnBottom
            bottom: !Config.options.bar.vertical && barOnBottom
        }

        implicitWidth: visualWidth
        implicitHeight: visualHeight

        mask: Region {
            item: popupBackground
        }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        margins {
            left: {
                if (Config.options.bar.vertical)
                    return Appearance.sizes.verticalBarWidth;
                return snapRight ? 0 : Math.max(4, centeredLeft);
            }
            top: {
                if (!Config.options.bar.vertical)
                    return barOnBottom ? 0 : Appearance.sizes.barHeight + 4;
                return root.hoverTarget?.mapToItem(
                    null,
                    0,
                    (root.hoverTarget.height - popupBackground.implicitHeight) / 2
                ).y ?? 4;
            }
            right: {
                if (Config.options.bar.vertical)
                    return Appearance.sizes.verticalBarWidth;
                return snapRight ? 4 : 0;
            }
            bottom: barOnBottom && !Config.options.bar.vertical ? Appearance.sizes.barHeight + 4 : 0
        }
        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay

        StyledRectangularShadow {
            target: popupBackground
        }

        Rectangle {
            id: popupBackground
            readonly property real margin: 8
            anchors {
                fill: parent
                leftMargin: root.popupBackgroundMargin * (!popupWindow.anchors.left)
                rightMargin: root.popupBackgroundMargin * (!popupWindow.anchors.right)
                topMargin: root.popupBackgroundMargin * (!popupWindow.anchors.top)
                bottomMargin: root.popupBackgroundMargin * (!popupWindow.anchors.bottom)
            }
            implicitWidth: root.contentItem.implicitWidth + margin * 2
            implicitHeight: root.contentItem.implicitHeight + margin * 2
            color: TuiStyle.bg
            radius: TuiStyle.radius
            children: [root.contentItem]
            clip: true

            border.width: TuiStyle.borderWidth
            border.color: TuiStyle.line
        }
    }
}
