pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
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
    property bool compactMode: false
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

    // ── Adaptive scaling ──
    // In full-screen mode, keep workspace aspect ratio (same as the real screen)
    // and compute the largest thumbnail that fits, then center the grid.
    // In compact mode, use the config scale value.
    readonly property real screenW: monitorData?.transform % 2 === 1
        ? (monitor.height - (monitorData?.reserved[0] ?? 0) - (monitorData?.reserved[2] ?? 0))
        : (monitor.width - (monitorData?.reserved[0] ?? 0) - (monitorData?.reserved[2] ?? 0))
    readonly property real screenH: monitorData?.transform % 2 === 1
        ? (monitor.width - (monitorData?.reserved[1] ?? 0) - (monitorData?.reserved[3] ?? 0))
        : (monitor.height - (monitorData?.reserved[1] ?? 0) - (monitorData?.reserved[3] ?? 0))

    readonly property real gridPadding: root.compactMode ? 10 : 24
    readonly property real containerMargin: root.compactMode ? Appearance.sizes.elevationMargin : 64

    // Usable area for the grid (after margins)
    readonly property real availW: root.compactMode
        ? (screenW * Config.options.overview.scale / (monitor.scale ?? 1))
        : (root.width - containerMargin * 2)
    readonly property real availH: root.compactMode
        ? (screenH * Config.options.overview.scale / (monitor.scale ?? 1))
        : (root.height - containerMargin * 2)

    // How big would each thumbnail be if we fill width vs height?
    // Workspaces keep the real screen aspect ratio (screenW : screenH).
    readonly property real thumbByWidth: root.compactMode
        ? (screenW * Config.options.overview.scale / (monitor.scale ?? 1))
        : ((availW - gridPadding * (overviewGridColumns - 1)) / overviewGridColumns)
    readonly property real thumbByHeight: root.compactMode
        ? (screenH * Config.options.overview.scale / (monitor.scale ?? 1))
        : ((availH - gridPadding * (overviewGridRows - 1)) / overviewGridRows)

    // Pick the smaller so the aspect ratio is preserved — thumbnails shrink
    // when there are many workspaces, grow when there are few.
    readonly property real workspaceImplicitWidth: Math.floor(Math.min(thumbByWidth, thumbByHeight * (screenW / screenH)))
    readonly property real workspaceImplicitHeight: Math.floor(workspaceImplicitWidth * (screenH / screenW))

    property real scale: root.compactMode
        ? Config.options.overview.scale
        : (workspaceImplicitWidth / (screenW / (monitor.scale ?? 1)))

    property real largeWorkspaceRadius: Appearance.rounding.large
    property real smallWorkspaceRadius: Appearance.rounding.verysmall

    property real workspaceNumberMargin: 80
    property real workspaceNumberSize: 250 * (monitor.scale ?? 1)
    property int workspaceZ: 0
    property int windowZ: 1
    property int windowDraggingZ: 99999
    property real workspaceSpacing: root.compactMode ? 5 : gridPadding

    implicitWidth: root.compactMode
        ? (overviewBackground.implicitWidth + Appearance.sizes.elevationMargin * 2)
        : root.width
    implicitHeight: root.compactMode
        ? (overviewBackground.implicitHeight + Appearance.sizes.elevationMargin * 2)
        : root.height

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
        WorkspaceNavigation.navigateByIndex(dir, false);
    }

    function dispatchFocusWorkspace(wsId) {
        WorkspaceNavigation.dispatchFocusWorkspace(wsId);
    }

    property color activeBorderColor: Appearance.colors.colSecondary

    property Component windowComponent: OverviewWindow {}
    property list<OverviewWindow> windowWidgets: []

    // ── Compact mode: shadow + rounded background container ──
    Loader {
        active: root.compactMode
        sourceComponent: StyledRectangularShadow {
            target: overviewBackground
        }
    }
    Rectangle { // Background (compact mode only)
        id: overviewBackground
        property real padding: 10
        visible: root.compactMode
        anchors.centerIn: parent
        anchors.margins: root.compactMode ? Appearance.sizes.elevationMargin : 0

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
    }

    // ── Full-screen mode: wheel scroll anywhere cycles workspaces ──
    MouseArea {
        anchors.fill: parent
        z: -1
        visible: !root.compactMode
        acceptedButtons: Qt.NoButton
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

    // Workspace grid — centered in both modes
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
                    clip: true

                    // Wallpaper background for empty workspaces
                    Image {
                        anchors.fill: parent
                        source: workspace.isTrailingEmpty ? "" : FileUtils.expandHomePath(Config.options.background.wallpaperPath)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        mipmap: true
                        visible: !workspace.isTrailingEmpty
                    }

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
                            WorkspaceNavigation.setDragTarget(workspace.workspaceValue, workspace.isTrailingEmpty)
                            if (GlobalStates.overviewDraggingFromWorkspace == GlobalStates.overviewDraggingTargetWorkspace) return;
                            hoveredWhileDragging = true
                        }
                        onExited: {
                            hoveredWhileDragging = false
                            WorkspaceNavigation.clearDragTarget(workspace.workspaceValue)
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
                            WorkspaceNavigation.beginWindowDrag(windowData?.workspace.id)
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
                            if (WorkspaceNavigation.commitWindowDrag(window.windowData?.address, windowData?.workspace.id, targetWorkspace, targetIsTrailing)) {
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
                                WorkspaceNavigation.focusWindow(windowData);
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
