pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

/**
 * A generic hover info popup that mirrors the tray tooltip behavior.
 *
 * Each module registers its hover content via HoverInfoService, then embeds
 * this popup inside the bar button. On hover, the registered Component is
 * loaded into a layershell overlay anchored to the bar edge.
 *
 * Usage:
 *   Component { id: hoverInfo; MyHoverContent {} }
 *   Component.onCompleted: HoverInfoService.register("myModule", hoverInfo)
 *   Component.onDestruction: HoverInfoService.unregister("myModule")
 *
 *   HoverInfoPopup {
 *       moduleId: "myModule"
 *       hoverTarget: myButton   // RippleButton or MouseArea
 *   }
 */
Item {
    id: root

    /// Module ID whose registered component to load.
    property string moduleId: ""
    /// Item whose hover state triggers the popup.
    property Item hoverTarget: null
    /// Delay before the popup appears (ms). 0 = immediate.
    property int hoverDelayMs: 400
    /// Extra margin inside the popup background.
    property real padding: 8

    readonly property var _providerComponent: moduleId.length > 0
        ? HoverInfoService.provider(moduleId)
        : null

    readonly property bool _visible: hoverTarget !== null
        && _providerComponent !== null
        && (hoverTarget.hovered !== undefined
            ? hoverTarget.hovered
            : hoverTarget.containsMouse === true)
        && !GlobalStates.screenLocked

    readonly property var targetScreen: hoverTarget?.QsWindow?.window?.screen
        ?? Quickshell.screens[0]

    // ── Lazy-loaded PanelWindow ──

    Loader {
        id: popupLoader
        anchors.fill: parent
        active: root._visible

        sourceComponent: PanelWindow {
            id: popupWindow
            screen: root.targetScreen
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:tooltip"
            WlrLayershell.layer: WlrLayer.Overlay

            readonly property bool barOnBottom: Config.options.bar.bottom
            readonly property bool barVertical: Config.options.bar.vertical

            readonly property real _visualWidth: popupBackground.implicitWidth + root.padding * 2
            readonly property real _visualHeight: popupBackground.implicitHeight + root.padding * 2

            readonly property real _centeredLeft: {
                if (barVertical)
                    return Appearance.sizes.verticalBarWidth;
                if (!root.hoverTarget)
                    return 4;
                const windowContent = root.hoverTarget.QsWindow?.window?.contentItem ?? null;
                const xOffset = (root.hoverTarget.width - _visualWidth) / 2;
                const globalX = windowContent
                    ? root.hoverTarget.mapToItem(windowContent, xOffset, 0).x
                    : (root.hoverTarget.mapToItem(null, xOffset, 0).x ?? 4);
                return Math.max(4, globalX);
            }
            readonly property bool _snapRight: !barVertical
                && _centeredLeft + _visualWidth > (targetScreen?.width ?? 1920) - 4;

            // ── sizing ──
            implicitWidth: _visualWidth
            implicitHeight: _visualHeight

            // ── anchors against the bar edge ──
            anchors {
                left: barVertical ? !barOnBottom : !_snapRight
                right: barVertical ? barOnBottom : _snapRight
                top: barVertical || !barOnBottom
                bottom: !barVertical && barOnBottom
            }

            // ── margins (actual screen position) ──
            margins {
                left: {
                    if (barVertical)
                        return Appearance.sizes.verticalBarWidth;
                    return _snapRight ? 0 : Math.max(4, _centeredLeft);
                }
                top: {
                    if (barVertical) {
                        if (!root.hoverTarget)
                            return 4;
                        const windowContent = root.hoverTarget.QsWindow?.window?.contentItem ?? null;
                        const globalY = windowContent
                            ? root.hoverTarget.mapToItem(windowContent, 0, (root.hoverTarget.height - _visualHeight) / 2).y
                            : (root.hoverTarget.mapToItem(null, 0, (root.hoverTarget.height - _visualHeight) / 2).y ?? 4);
                        return Math.max(4, globalY);
                    }
                    return barOnBottom ? 0 : Appearance.sizes.barHeight + 4;
                }
                right: {
                    if (barVertical)
                        return Appearance.sizes.verticalBarWidth;
                    return _snapRight ? 4 : 0;
                }
                bottom: barOnBottom && !barVertical ? Appearance.sizes.barHeight + 4 : 0
            }

            // ── fade-in animation ──
            Item {
                id: animationRoot
                anchors.fill: parent
                opacity: 0

                Timer {
                    interval: root.hoverDelayMs
                    repeat: false
                    running: true
                    onTriggered: animationRoot.opacity = 1
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }

                // ── shadow ──
                StyledRectangularShadow {
                    target: popupBackground
                }

                // ── background ──
                Rectangle {
                    id: popupBackground
                    anchors.fill: parent
                    anchors.margins: root.padding
                    color: TuiStyle.panel
                    radius: 6
                    border.width: 0
                    clip: true

                    implicitWidth: popupContent.implicitWidth + 16
                    implicitHeight: popupContent.implicitHeight + 16

                    // ── registered content ──
                    Loader {
                        id: popupContent
                        anchors {
                            fill: parent
                            margins: 8
                        }
                        sourceComponent: root._providerComponent
                    }
                }
            }
        }
    }
}
