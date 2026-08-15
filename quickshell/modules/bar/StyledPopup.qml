pragma ComponentBehavior: Bound
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
    property real popupBackgroundMargin: Appearance.sizes.elevationMargin
    property bool alignRight: false
    property int hoverDelayMs: 500
    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        ?? Quickshell.screens[0]
        ?? null
    readonly property var targetScreen: hoverTarget?.QsWindow?.window?.screen ?? focusedScreen

    function globalToScreenX(globalX) {
        return globalX;
    }

    function globalToScreenY(globalY) {
        return globalY;
    }

    active: hoverTarget !== null
        && hoverTarget.containsMouse === true
        && GlobalStates.barPopupType === ""
        && !GlobalStates.screenLocked

    component: PanelWindow {
        id: popupWindow
        screen: root.targetScreen
        color: "transparent"

        readonly property bool barOnBottom: Config.options.bar.bottom
        readonly property real visualWidth: popupBackground.implicitWidth + root.popupBackgroundMargin * 2
        readonly property real visualHeight: popupBackground.implicitHeight + root.popupBackgroundMargin * 2
        readonly property real centeredLeft: {
            if (Config.options.bar.vertical)
                return Appearance.sizes.verticalBarWidth;
            const xOffset = root.alignRight
                ? root.hoverTarget.width - visualWidth
                : (root.hoverTarget.width - visualWidth) / 2;
            const windowContent = root.hoverTarget?.QsWindow?.window?.contentItem ?? null;
            const globalX = windowContent
                ? root.hoverTarget.mapToItem(windowContent, xOffset, 0).x
                : (root.hoverTarget?.mapToItem(null, xOffset, 0).x ?? 4);
            return root.globalToScreenX(globalX);
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
                const windowContent = root.hoverTarget?.QsWindow?.window?.contentItem ?? null;
                const globalY = windowContent
                    ? root.hoverTarget.mapToItem(windowContent, 0, (root.hoverTarget.height - visualHeight) / 2).y
                    : (root.hoverTarget?.mapToItem(null, 0, (root.hoverTarget.height - visualHeight) / 2).y ?? 4);
                return root.globalToScreenY(globalY);
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

        Item {
            id: popupLayer
            opacity: 0
            anchors.fill: parent

            Timer {
                interval: root.hoverDelayMs
                repeat: false
                running: true
                onTriggered: popupLayer.opacity = 1
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }

            StyledRectangularShadow {
                target: popupBackground
            }

            Rectangle {
                id: popupBackground
                readonly property real margin: 8
                anchors {
                    fill: parent
                    margins: root.popupBackgroundMargin
                }
                implicitWidth: root.contentItem.implicitWidth + margin * 2
                implicitHeight: root.contentItem.implicitHeight + margin * 2
                color: TuiStyle.panel
                radius: 6
                children: [root.contentItem]
                clip: true

                border.width: 0
            }
        }
    }
}
