pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: root
    required property var screen
    property real wheelAccum: 0
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property var toplevels: ToplevelManager.toplevels
    // Clamp to avoid lock-screen temp workspace (2147483647 - N) leaking into UI
    readonly property int effectiveActiveWorkspaceId: Math.max(1, Math.min(100, monitor?.activeWorkspace?.id ?? 1))
    readonly property int highlightedWorkspaceId: (GlobalStates.overviewFocusedWorkspaceId > 0
        ? GlobalStates.overviewFocusedWorkspaceId
        : effectiveActiveWorkspaceId)
    readonly property var overviewEntries: HyprlandData.overviewWorkspaceEntriesGlobal()
    readonly property var overviewEntryIds: root.overviewEntries.map(entry => entry.id)
    readonly property int overviewGridColumns: Math.min(
        Math.max(root.overviewEntries.length, 1),
        Config.options.overview.columns)
    readonly property int overviewGridRows: Math.max(
        1,
        Math.ceil(root.overviewEntries.length / root.overviewGridColumns))
    property bool monitorIsFocused: (Hyprland.focusedMonitor?.name == monitor?.name)
    property var windows: HyprlandData.windowList
    property var windowByAddress: HyprlandData.windowByAddress
    property var windowAddresses: HyprlandData.addresses
    property var monitorData: HyprlandData.monitors.find(m => m.id === root.monitor?.id)
    property real scale: Config.options.overview.scale
    property color activeBorderColor: Appearance.colors.colSecondary

    property real workspaceImplicitWidth: (monitorData?.transform % 2 === 1) ? 
        ((monitor.height - monitorData?.reserved[0] - monitorData?.reserved[2]) * root.scale / monitor.scale) :
        ((monitor.width - monitorData?.reserved[0] - monitorData?.reserved[2]) * root.scale / monitor.scale)
    property real workspaceImplicitHeight: (monitorData?.transform % 2 === 1) ? 
        ((monitor.width - monitorData?.reserved[1] - monitorData?.reserved[3]) * root.scale / monitor.scale) :
        ((monitor.height - monitorData?.reserved[1] - monitorData?.reserved[3]) * root.scale / monitor.scale)
    property real largeWorkspaceRadius: Appearance.rounding.large
    property real smallWorkspaceRadius: Appearance.rounding.verysmall

    property real workspaceNumberMargin: 80
    property real workspaceNumberSize: 250 * monitor.scale
    property int workspaceZ: 0
    property int windowZ: 1
    property int windowDraggingZ: 99999
    property real workspaceSpacing: 5

    implicitWidth: overviewBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: overviewBackground.implicitHeight + Appearance.sizes.elevationMargin * 2

    readonly property bool overviewNavigationActive: GlobalStates.overviewOpen

    function indexForWorkspaceId(wsId) {
        for (let i = 0; i < root.overviewEntries.length; ++i) {
            if (root.overviewEntries[i].id === wsId)
                return i;
        }
        return 0;
    }

    function getEntryRow(entryIndex) {
        const cols = root.overviewGridColumns;
        const normalRow = Math.floor(entryIndex / cols);
        return Config.options.overview.orderBottomUp
            ? root.overviewGridRows - normalRow - 1
            : normalRow;
    }

    function getEntryColumn(entryIndex) {
        const cols = root.overviewGridColumns;
        const normalCol = entryIndex % cols;
        return Config.options.overview.orderRightLeft
            ? cols - normalCol - 1
            : normalCol;
    }

    function cycleOverviewWorkspace(dir) {
        const model = root.overviewEntries.filter(entry => !entry.isTrailingEmpty);
        if (model.length === 0)
            return;

        const ws = GlobalStates.overviewFocusedWorkspaceId > 0
            ? GlobalStates.overviewFocusedWorkspaceId
            : effectiveActiveWorkspaceId;
        let idx = -1;
        for (let i = 0; i < model.length; ++i) {
            if (model[i].id === ws) {
                idx = i;
                break;
            }
        }
        if (idx === -1)
            idx = 0;
        idx = (idx + dir + model.length) % model.length;
        const newWs = model[idx].id;
        GlobalStates.overviewFocusedWorkspaceId = newWs;
    }

    function dispatchFocusWorkspace(wsId) {
        if (wsId < 1)
            return;
        const ws = HyprlandData.workspaceDataForId(wsId);
        if (ws?.monitor)
            Hyprland.dispatch(`hl.dsp.focus({monitor="${ws.monitor}"})`);
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${wsId} })`);
    }

    property Component windowComponent: OverviewWindow {}
    property list<OverviewWindow> windowWidgets: []

    StyledRectangularShadow {
        target: overviewBackground
    }
    Rectangle { // Background
        id: overviewBackground
        property real padding: 10
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin

        implicitWidth: workspaceColumnLayout.implicitWidth + padding * 2
        implicitHeight: workspaceColumnLayout.implicitHeight + padding * 2
        radius: root.largeWorkspaceRadius + padding
        color: Appearance.colors.colBackgroundSurfaceContainer

        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.NoButton
            enabled: root.overviewNavigationActive
            onWheel: wheel => {
                const r = WheelUtils.getSteps(wheel.angleDelta.y, root.wheelAccum)
                root.wheelAccum = r.accum
                if (r.steps > 0)
                    Hyprland.dispatch("hl.dsp.global('quickshell:overviewPrev')")
                else if (r.steps < 0)
                    Hyprland.dispatch("hl.dsp.global('quickshell:overviewNext')")
                wheel.accepted = true
            }
        }

        GridLayout { // Workspaces
            id: workspaceColumnLayout

            z: root.workspaceZ
            anchors.centerIn: parent
            columns: root.overviewGridColumns
            rowSpacing: workspaceSpacing
            columnSpacing: workspaceSpacing

            Repeater {
                model: root.overviewEntries
                delegate: Rectangle { // Workspace
                    id: workspace
                    required property var modelData
                    required property int index
                    property int workspaceValue: modelData.id
                    property string monitorName: modelData.monitorName ?? ""
                    property bool isTrailingEmpty: modelData.isTrailingEmpty ?? false
                    property int colIndex: root.getEntryColumn(index)
                    property int rowIndex: root.getEntryRow(index)
                    property color defaultWorkspaceColor: Appearance.colors.colSurfaceContainerLow
                    property color hoveredWorkspaceColor: ColorUtils.mix(defaultWorkspaceColor, Appearance.colors.colLayer1Hover, 0.1)
                    property color hoveredBorderColor: Appearance.colors.colLayer2Hover
                    property bool hoveredWhileDragging: false

                    Layout.row: root.getEntryRow(index)
                    Layout.column: root.getEntryColumn(index)
                    implicitWidth: root.workspaceImplicitWidth
                    implicitHeight: root.workspaceImplicitHeight
                    color: hoveredWhileDragging ? hoveredWorkspaceColor : defaultWorkspaceColor
                    property bool workspaceAtLeft: colIndex === 0
                    property bool workspaceAtRight: colIndex === root.overviewGridColumns - 1
                    property bool workspaceAtTop: rowIndex === 0
                    property bool workspaceAtBottom: rowIndex === root.overviewGridRows - 1
                    topLeftRadius: (workspaceAtLeft && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                    topRightRadius: (workspaceAtRight && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                    bottomLeftRadius: (workspaceAtLeft && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                    bottomRightRadius: (workspaceAtRight && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                    border.width: 2
                    border.color: hoveredWhileDragging ? hoveredBorderColor : "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: workspace.isTrailingEmpty ? "+" : ""
                        font {
                            pixelSize: root.workspaceNumberSize * root.scale
                            weight: Font.DemiBold
                            family: Appearance.font.family.expressive
                        }
                        color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.8)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    StyledText {
                        anchors {
                            top: parent.top
                            left: parent.left
                            margins: 8
                        }
                        text: workspace.isTrailingEmpty
                            ? Translation.tr("New workspace")
                            : `${workspace.monitorName || Translation.tr("Hidden")} · ${workspace.workspaceValue}`
                        font {
                            pixelSize: Appearance.font.pixelSize.smaller
                            weight: Font.Medium
                        }
                        color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.22)
                    }

                    MouseArea {
                        id: workspaceArea
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onPressed: {
                            if (GlobalStates.overviewDraggingTargetWorkspace === -1) {
                                if (workspace.isTrailingEmpty) {
                                    GlobalStates.overviewOpen = false;
                                    Hyprland.dispatch(`hl.dsp.focus({ workspace = "empty" })`);
                                } else {
                                    GlobalStates.promoteWorkspaceMru(workspace.workspaceValue);
                                    GlobalStates.overviewOpen = false;
                                    root.dispatchFocusWorkspace(workspace.workspaceValue);
                                }
                            }
                        }
                    }

                    DropArea {
                        anchors.fill: parent
                        onEntered: {
                            GlobalStates.overviewDraggingTargetWorkspace = workspace.workspaceValue
                            GlobalStates.overviewDraggingTargetIsTrailing = workspace.isTrailingEmpty
                            if (GlobalStates.overviewDraggingFromWorkspace == GlobalStates.overviewDraggingTargetWorkspace) return;
                            hoveredWhileDragging = true
                        }
                        onExited: {
                            hoveredWhileDragging = false
                            if (GlobalStates.overviewDraggingTargetWorkspace == workspace.workspaceValue) {
                                GlobalStates.overviewDraggingTargetWorkspace = -1
                                GlobalStates.overviewDraggingTargetIsTrailing = false
                            }
                        }
                    }
                }
            }
        }

        Item { // Windows & focused workspace indicator
            id: windowSpace
            anchors.centerIn: parent
            implicitWidth: workspaceColumnLayout.implicitWidth
            implicitHeight: workspaceColumnLayout.implicitHeight

            Repeater { // Window repeater
                model: ScriptModel {
                    values: {
                        // console.log(JSON.stringify(ToplevelManager.toplevels.values.map(t => t), null, 2))
                        return ToplevelManager.toplevels.values.filter((toplevel) => {
                            const address = `0x${toplevel.HyprlandToplevel?.address}`
                            var win = windowByAddress[address]
                            if (!win?.workspace?.id)
                                return false;
                            return root.overviewEntryIds.includes(win.workspace.id);
                        })
                    }
                }
                delegate: OverviewWindow {
                    id: window
                    required property var modelData
                    property int monitorId: windowData?.monitor
                    property var monitor: HyprlandData.monitors.find(m => m.id == monitorId)
                    property var address: `0x${modelData.HyprlandToplevel.address}`
                    toplevel: modelData
                    monitorData: this.monitor
                    scale: root.scale
                    widgetMonitor: HyprlandData.monitors.find(m => m.id == root.monitor.id)
                    windowData: windowByAddress[address]

                    property bool atInitPosition: (initX == x && initY == y)

                    // Offset on the canvas
                    property int workspaceEntryIndex: root.indexForWorkspaceId(windowData?.workspace.id)
                    property int workspaceColIndex: root.getEntryColumn(workspaceEntryIndex)
                    property int workspaceRowIndex: root.getEntryRow(workspaceEntryIndex)
                    xOffset: (root.workspaceImplicitWidth + workspaceSpacing) * workspaceColIndex
                    yOffset: (root.workspaceImplicitHeight + workspaceSpacing) * workspaceRowIndex
                    property real xWithinWorkspaceWidget: Math.max((windowData?.at[0] - (monitor?.x ?? 0) - monitorData?.reserved[0]) * window.widthRatio * root.scale, 0)
                    property real yWithinWorkspaceWidget: Math.max((windowData?.at[1] - (monitor?.y ?? 0) - monitorData?.reserved[1]) * window.heightRatio * root.scale, 0)

                    // Radius
                    property real minRadius: Appearance.rounding.small
                    property bool workspaceAtLeft: workspaceColIndex === 0
                    property bool workspaceAtRight: workspaceColIndex === root.overviewGridColumns - 1
                    property bool workspaceAtTop: workspaceRowIndex === 0
                    property bool workspaceAtBottom: workspaceRowIndex === Config.options.overview.rows - 1
                    property bool workspaceAtTopLeft: (workspaceAtLeft && workspaceAtTop) 
                    property bool workspaceAtTopRight: (workspaceAtRight && workspaceAtTop) 
                    property bool workspaceAtBottomLeft: (workspaceAtLeft && workspaceAtBottom) 
                    property bool workspaceAtBottomRight: (workspaceAtRight && workspaceAtBottom) 
                    property real distanceFromLeftEdge: xWithinWorkspaceWidget
                    property real distanceFromRightEdge: root.workspaceImplicitWidth - (xWithinWorkspaceWidget + targetWindowWidth)
                    property real distanceFromTopEdge: yWithinWorkspaceWidget
                    property real distanceFromBottomEdge: root.workspaceImplicitHeight - (yWithinWorkspaceWidget + targetWindowHeight)
                    property real distanceFromTopLeftCorner: Math.max(distanceFromLeftEdge, distanceFromTopEdge)
                    property real distanceFromTopRightCorner: Math.max(distanceFromRightEdge, distanceFromTopEdge)
                    property real distanceFromBottomLeftCorner: Math.max(distanceFromLeftEdge, distanceFromBottomEdge)
                    property real distanceFromBottomRightCorner: Math.max(distanceFromRightEdge, distanceFromBottomEdge)
                    topLeftRadius: Math.max((workspaceAtTopLeft ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromTopLeftCorner, minRadius)
                    topRightRadius: Math.max((workspaceAtTopRight ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromTopRightCorner, minRadius)
                    bottomLeftRadius: Math.max((workspaceAtBottomLeft ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromBottomLeftCorner, minRadius)
                    bottomRightRadius: Math.max((workspaceAtBottomRight ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromBottomRightCorner, minRadius)

                    Timer {
                        id: updateWindowPosition
                        interval: Config.options.hacks.arbitraryRaceConditionDelay
                        repeat: false
                        running: false
                        onTriggered: {
                            window.x = Math.round(xWithinWorkspaceWidget + xOffset)
                            window.y = Math.round(yWithinWorkspaceWidget + yOffset)
                        }
                    }

                    z: Drag.active ? root.windowDraggingZ : (root.windowZ + windowData?.floating + windowData?.fullscreen * 2)
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: hovered = true // For hover color change
                        onExited: hovered = false // For hover color change
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        drag.target: parent
                        onPressed: (mouse) => {
                            GlobalStates.overviewDraggingFromWorkspace = windowData?.workspace.id
                            window.pressed = true
                            window.Drag.active = true
                            window.Drag.source = window
                            window.Drag.hotSpot.x = mouse.x
                            window.Drag.hotSpot.y = mouse.y
                            // console.log(`[OverviewWindow] Dragging window ${windowData?.address} from position (${window.x}, ${window.y})`)
                        }
                        onReleased: {
                            const targetWorkspace = GlobalStates.overviewDraggingTargetWorkspace
                            const targetIsTrailing = GlobalStates.overviewDraggingTargetIsTrailing
                            window.pressed = false
                            window.Drag.active = false
                            GlobalStates.overviewDraggingFromWorkspace = -1
                            GlobalStates.overviewDraggingTargetWorkspace = -1
                            GlobalStates.overviewDraggingTargetIsTrailing = false
                            if (targetWorkspace !== -1 && targetWorkspace !== windowData?.workspace.id) {
                                if (targetIsTrailing) {
                                    Hyprland.dispatch(`hl.dsp.window.move({ workspace = "empty", follow = false, window = "address:${window.windowData?.address}" })`)
                                } else {
                                    Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${targetWorkspace}, follow = false, window = "address:${window.windowData?.address}" })`)
                                }
                                updateWindowPosition.restart()
                            }
                            else {
                                if (!window.windowData.floating) {
                                    updateWindowPosition.restart()
                                    return
                                }
                                const percentageX = (window.x - xOffset) / root.workspaceImplicitWidth
                                const percentageY = (window.y - yOffset) / root.workspaceImplicitHeight
                                Hyprland.dispatch(`hl.dsp.window.move({ x = "${percentageX * (monitor?.width ?? root.screen.width)}", y = "${percentageY * (monitor?.height ?? root.screen.height)}", window = "address:${window.windowData?.address}" })`)
                            }
                        }
                        onClicked: (event) => {
                            if (!windowData) return;

                            if (event.button === Qt.LeftButton) {
                                GlobalStates.overviewOpen = false;
                                if (windowData?.workspace?.id > 0)
                                    GlobalStates.promoteWorkspaceMru(windowData.workspace.id);
                                Hyprland.dispatch(`hl.dsp.focus({window = "address:${windowData.address}"})`);
                                event.accepted = true;
                            } else if (event.button === Qt.MiddleButton) {
                                Hyprland.dispatch(`hl.dsp.window.close({window = "address:${windowData.address}"})`)
                                event.accepted = true
                            }
                        }

                        StyledToolTip {
                            extraVisibleCondition: false
                            alternativeVisibleCondition: dragArea.containsMouse && !window.Drag.active
                            text: `${windowData?.title}\n[${windowData?.class}] ${windowData?.xwayland ? "[XWayland] " : ""}`
                        }
                    }
                }
            }

            Rectangle { // Focused workspace indicator
                id: focusedWorkspaceIndicator
                property int entryIndex: root.indexForWorkspaceId(root.highlightedWorkspaceId)
                property int rowIndex: root.getEntryRow(entryIndex)
                property int colIndex: root.getEntryColumn(entryIndex)
                x: (root.workspaceImplicitWidth + workspaceSpacing) * colIndex
                y: (root.workspaceImplicitHeight + workspaceSpacing) * rowIndex
                z: root.windowZ
                width: root.workspaceImplicitWidth
                height: root.workspaceImplicitHeight
                color: "transparent"
                property bool workspaceAtLeft: colIndex === 0
                property bool workspaceAtRight: colIndex === root.overviewGridColumns - 1
                property bool workspaceAtTop: rowIndex === 0
                property bool workspaceAtBottom: rowIndex === root.overviewGridRows - 1
                topLeftRadius: (workspaceAtLeft && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                topRightRadius: (workspaceAtRight && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                bottomLeftRadius: (workspaceAtLeft && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                bottomRightRadius: (workspaceAtRight && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                border.width: 2
                border.color: root.activeBorderColor
                Behavior on x {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on y {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on topLeftRadius {
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on topRightRadius {
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on bottomLeftRadius {
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on bottomRightRadius {
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
            }
        }
    }
}
