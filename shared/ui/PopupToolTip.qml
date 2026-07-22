pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Item {
    id: root
    property string text: ""
    property bool extraVisibleCondition: true
    property bool alternativeVisibleCondition: false
    property real horizontalPadding: 10
    property real verticalPadding: 5
    property real horizontalMargin: horizontalPadding
    property real verticalMargin: verticalPadding

    function updateAnchor() {
        tooltipLoader.item?.updateAnchor();
    }

    readonly property bool internalVisibleCondition: (extraVisibleCondition && (parent.hovered === undefined || parent?.hovered)) || alternativeVisibleCondition
    property var anchorEdges: Edges.Top
    property var anchorGravity: anchorEdges

    readonly property var targetScreen: root.parent?.QsWindow?.window?.screen ?? Quickshell.screens[0]

    property Item contentItem: StyledToolTipContent {
        id: contentItem
        anchors.centerIn: parent
        text: root.text
        shown: false
        Component.onCompleted: shown = true
        horizontalPadding: root.horizontalPadding
        verticalPadding: root.verticalPadding
    }

    Loader {
        id: tooltipLoader
        anchors.fill: parent
        active: root.internalVisibleCondition
        sourceComponent: PanelWindow {
            id: popupWindow
            screen: root.targetScreen
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:tooltip"
            WlrLayershell.layer: WlrLayer.Overlay

            readonly property real visualWidth: root.contentItem.implicitWidth + root.horizontalMargin * 2
            readonly property real visualHeight: root.contentItem.implicitHeight + root.verticalMargin * 2
            readonly property bool barOnBottom: Config.options.bar.bottom
            readonly property bool barVertical: Config.options.bar.vertical

            anchors {
                left: !barVertical
                right: false
                top: !barOnBottom
                bottom: barOnBottom
            }

            implicitWidth: visualWidth
            implicitHeight: visualHeight

            function updateAnchor() {
                popupWindow.margins = popupWindow.margins;
            }

            margins {
                left: {
                    const parentItem = root.parent;
                    if (!parentItem) return 4;
                    const windowContent = parentItem.QsWindow?.window?.contentItem ?? null;
                    const iconCenterLocalX = windowContent
                        ? parentItem.mapToItem(windowContent, parentItem.width / 2, 0).x
                        : parentItem.mapToItem(null, parentItem.width / 2, 0).x;
                    const tooltipLeftLocalX = iconCenterLocalX - popupWindow.visualWidth / 2;
                    const maxLeft = Math.max(4, (root.targetScreen?.width ?? 1920) - popupWindow.visualWidth - 4);
                    return Math.min(maxLeft, Math.max(4, tooltipLeftLocalX));
                }
                top: {
                    if (barOnBottom) return 0;
                    return Appearance.sizes.barHeight + 4;
                }
                bottom: barOnBottom ? Appearance.sizes.barHeight + 4 : 0
                right: 0
            }

            Item {
                anchors.fill: parent

                StyledToolTipContent {
                    anchors.centerIn: parent
                    text: root.text
                    shown: true
                    horizontalPadding: root.horizontalPadding
                    verticalPadding: root.verticalPadding
                }
            }
        }
    }
}
