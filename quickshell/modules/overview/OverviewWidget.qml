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
    property real wheelAccum: 0
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property var toplevels: ToplevelManager.toplevels
    // Performance mode disables expensive per-window effects (live screencopy,
    // OpacityMask, wallpaper Image) in exchange for faster overview opens.
    readonly property bool perfMode: (Persistent.states?.display?.optimization ?? "balanced") === "performance"
    // Re-evaluate the model only when the HyprlandData dirty-flag, an
    // explicit overview refresh, or the toplevel count changes. The
    // dependencies are read explicitly so QML registers them; the actual
    // data comes from cached/computed sources.
    readonly property int modelRevision: HyprlandData.dataSerial
        + GlobalStates.overviewRefreshSerial
        + (ToplevelManager.toplevels.values?.length ?? 0)
    // Clamp to avoid lock-screen temp workspace (2147483647 - N) leaking into UI
    readonly property int effectiveActiveWorkspaceId: Math.max(1, Math.min(100, monitor?.activeWorkspace?.id ?? 1))
    readonly property var overviewEntries: {
        // Register the revision as a dependency without the comma-operator hack.
        const _rev = root.modelRevision;
        void _rev;
        if (OverviewSwitchingController.grabbed)
            return WorkspaceNavigation.switchingModeModel() ?? [];
        return HyprlandData.overviewWorkspaceEntries ?? [];
    }
    readonly property var overviewEntryIds: (root.overviewEntries ?? []).map(entry => entry.id)
    readonly property var monitorGroups: {
        const groups = [];
        const byKey = {};
        for (let i = 0; i < root.overviewEntries.length; ++i) {
            const entry = root.overviewEntries[i];
            const key = entry.monitorName || "unknown";
            if (!byKey[key]) {
                byKey[key] = {
                    key,
                    label: entry.monitorLabel || entry.monitorName || "Hidden monitor",
                    start: i,
                    end: i,
                    monitorIndex: entry.monitorIndex ?? groups.length
                };
                groups.push(byKey[key]);
            }
            byKey[key].end = i;
        }
        return groups;
    }
    readonly property var localMonitorGroup: {
        const monitorName = root.monitor?.name ?? "";
        for (let i = 0; i < root.monitorGroups.length; ++i) {
            if (root.monitorGroups[i].key === monitorName)
                return root.monitorGroups[i];
        }
        return root.monitorGroups[0] ?? null;
    }
    readonly property int highlightedWorkspaceId: {
        if (OverviewSwitchingController.grabbed && GlobalStates.overviewFocusedWorkspaceId > 0)
            return GlobalStates.overviewFocusedWorkspaceId;
        const group = root.localMonitorGroup;
        const entry = group ? root.overviewEntries[group.start] : null;
        return entry?.id ?? root.effectiveActiveWorkspaceId;
    }
    property bool monitorIsFocused: (Hyprland.focusedMonitor?.name == monitor?.name)
    property var windows: HyprlandData.windowList
    property var windowByAddress: HyprlandData.windowByAddress
    property var windowAddresses: HyprlandData.addresses
    property var monitorData: HyprlandData.monitors.find(m => m.id === root.monitor?.id)

    // ── Adaptive scaling ──
    // Overview (工作区概览): full-screen grid, auto-select optimal columns
    // Overview switching mode (Win+Tab): current-monitor preview, use config scale value
    readonly property real screenW: monitorData?.transform % 2 === 1
        ? (monitor.height - (monitorData?.reserved[0] ?? 0) - (monitorData?.reserved[2] ?? 0))
        : (monitor.width - (monitorData?.reserved[0] ?? 0) - (monitorData?.reserved[2] ?? 0))
    readonly property real screenH: monitorData?.transform % 2 === 1
        ? (monitor.width - (monitorData?.reserved[1] ?? 0) - (monitorData?.reserved[3] ?? 0))
        : (monitor.height - (monitorData?.reserved[1] ?? 0) - (monitorData?.reserved[3] ?? 0))

    readonly property real gridPadding: 24
    readonly property real containerMargin: 64

    // Usable area for the grid (after margins)
    readonly property real availW: root.width - containerMargin * 2
    readonly property real availH: root.height - containerMargin * 2 - 72

    // Overview: try every column count, pick the one that gives the largest thumbnail
    readonly property int overviewGridColumns: {
        let n = Math.max(root.overviewEntries.length, 1);
        let bestCols = 1;
        let bestThumb = 0;
        for (let c = 1; c <= n; c++) {
            let rows = root.groupedRowsForColumns(c);
            let verticalOverhead = root.groupedVerticalOverheadForRows(rows);
            let tw = (availW - root.monitorSectionPaddingX * 2 - gridPadding * (c - 1)) / c;
            let th = (availH - verticalOverhead) / rows;
            let constrained = Math.min(tw, th / root.maxWorkspaceAspect);
            if (constrained > bestThumb) {
                bestThumb = constrained;
                bestCols = c;
            }
        }
        return bestCols;
    }
    readonly property int overviewGridRows: Math.max(
        1,
        Math.ceil(root.overviewEntries.length / root.overviewGridColumns))
    readonly property int monitorSectionGap: 24
    readonly property int monitorSectionPaddingX: 14
    readonly property int monitorSectionPaddingTop: 34
    readonly property int monitorSectionPaddingBottom: 14
    readonly property int groupedGridRows: root.groupedRowsForColumns(root.overviewGridColumns)
    readonly property real groupedVerticalOverhead: root.groupedVerticalOverheadForRows(root.groupedGridRows)
    readonly property real maxWorkspaceAspect: {
        if (root.monitorGroups.length === 0)
            return screenH / screenW;
        let aspect = screenH / screenW;
        for (let i = 0; i < root.monitorGroups.length; ++i)
            aspect = Math.max(aspect, root.monitorAspect(root.monitorGroups[i].key));
        return aspect;
    }

    // How big would each thumbnail be if we fill width vs height?
    // Workspaces keep the real screen aspect ratio (screenW : screenH).
    readonly property real thumbByWidth: (availW - gridPadding * (overviewGridColumns - 1)) / overviewGridColumns
    readonly property real thumbByHeight: (availH - groupedVerticalOverhead) / groupedGridRows

    // Pick the smaller so the aspect ratio is preserved — thumbnails shrink
    // when there are many workspaces, grow when there are few.
    readonly property real workspaceImplicitWidth: Math.floor(Math.min(thumbByWidth, thumbByHeight / maxWorkspaceAspect))
    readonly property real workspaceImplicitHeight: Math.floor(workspaceImplicitWidth * (screenH / screenW))

    property real scale: workspaceImplicitWidth / (screenW / (monitor.scale ?? 1))

    property real largeWorkspaceRadius: Appearance.rounding.large
    property real smallWorkspaceRadius: Appearance.rounding.verysmall

    property real workspaceNumberMargin: 80
    property real workspaceNumberSize: 250 * (monitor.scale ?? 1)
    property int workspaceZ: 0
    property int windowZ: 1
    property int windowDraggingZ: 99999
    property real workspaceSpacing: gridPadding

    implicitWidth: root.width
    implicitHeight: root.height

    readonly property bool overviewNavigationActive: GlobalStates.overviewOpen

    function groupedRowsForColumns(columns) {
        const cols = Math.max(1, columns);
        if (root.monitorGroups.length <= 1)
            return Math.max(1, Math.ceil(root.overviewEntries.length / cols));

        let rows = 0;
        for (let i = 0; i < root.monitorGroups.length; ++i) {
            const length = root.groupLength(root.monitorGroups[i]);
            const groupCols = Math.max(1, Math.min(length, cols));
            rows += Math.max(1, Math.ceil(length / groupCols));
        }
        return Math.max(1, rows);
    }

    function groupedVerticalOverheadForRows(rows) {
        const groupCount = Math.max(1, root.monitorGroups.length);
        return groupCount * (root.monitorSectionPaddingTop + root.monitorSectionPaddingBottom)
            + Math.max(0, groupCount - 1) * root.monitorSectionGap
            + Math.max(0, rows - groupCount) * root.workspaceSpacing;
    }

    function indexForWorkspaceId(wsId) {
        for (let i = 0; i < root.overviewEntries.length; ++i) {
            if (root.overviewEntries[i].id === wsId)
                return i;
        }
        return -1;
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

    function groupLength(group) {
        if (!group)
            return 0;
        return Math.max(0, group.end - group.start + 1);
    }

    function groupColumns(group) {
        if (!group)
            return Math.max(1, root.overviewGridColumns);
        return Math.max(1, Math.min(root.groupLength(group), root.overviewGridColumns));
    }

    function monitorDataForName(monitorName) {
        return HyprlandData.monitors.find(mon => (mon.name ?? "") === monitorName)
            ?? root.monitorData;
    }

    function monitorLogicalWidth(monitorName) {
        const mon = root.monitorDataForName(monitorName);
        if (!mon)
            return Math.max(1, root.screenW / (root.monitor?.scale ?? 1));
        const width = (mon.transform & 1) ? mon.height : mon.width;
        return Math.max(1, (width - (mon.reserved?.[0] ?? 0) - (mon.reserved?.[2] ?? 0)) / (mon.scale ?? 1));
    }

    function monitorLogicalHeight(monitorName) {
        const mon = root.monitorDataForName(monitorName);
        if (!mon)
            return Math.max(1, root.screenH / (root.monitor?.scale ?? 1));
        const height = (mon.transform & 1) ? mon.width : mon.height;
        return Math.max(1, (height - (mon.reserved?.[1] ?? 0) - (mon.reserved?.[3] ?? 0)) / (mon.scale ?? 1));
    }

    function monitorAspect(monitorName) {
        return root.monitorLogicalHeight(monitorName) / root.monitorLogicalWidth(monitorName);
    }

    function entryWidth(entryIndex) {
        return root.workspaceImplicitWidth;
    }

    function entryHeight(entryIndex) {
        const group = root.groupForEntry(entryIndex);
        return Math.floor(root.entryWidth(entryIndex) * root.monitorAspect(group?.key ?? ""));
    }

    function groupWorkspaceHeight(group) {
        return Math.floor(root.workspaceImplicitWidth * root.monitorAspect(group?.key ?? ""));
    }

    function groupRows(group) {
        return Math.max(1, Math.ceil(root.groupLength(group) / root.groupColumns(group)));
    }

    function groupWidth(group) {
        if (!group)
            return root.workspaceImplicitWidth;
        const cols = root.groupColumns(group);
        return root.workspaceImplicitWidth * cols
            + root.workspaceSpacing * (cols - 1)
            + root.monitorSectionPaddingX * 2;
    }

    function groupHeight(group) {
        if (!group)
            return root.workspaceImplicitHeight;
        const rows = root.groupRows(group);
        return root.groupWorkspaceHeight(group) * rows
            + root.workspaceSpacing * (rows - 1)
            + root.monitorSectionPaddingTop
            + root.monitorSectionPaddingBottom;
    }

    function groupsTotalHeight() {
        if (root.monitorGroups.length === 0)
            return root.overviewGridRows * root.workspaceImplicitHeight
                + (root.overviewGridRows - 1) * root.workspaceSpacing;

        let height = 0;
        for (let i = 0; i < root.monitorGroups.length; ++i) {
            if (i > 0)
                height += root.monitorSectionGap;
            height += root.groupHeight(root.monitorGroups[i]);
        }
        return height;
    }

    function groupForEntry(entryIndex) {
        for (let i = 0; i < root.monitorGroups.length; ++i) {
            const group = root.monitorGroups[i];
            if (entryIndex >= group.start && entryIndex <= group.end)
                return group;
        }
        return null;
    }

    function groupX(group) {
        if (!group)
            return root.containerMargin;
        return Math.max(root.containerMargin, (root.width - root.groupWidth(group)) / 2);
    }

    function groupY(group) {
        if (!group)
            return root.containerMargin;

        let y = Math.max(root.containerMargin, (root.height - root.groupsTotalHeight()) / 2);
        for (let i = 0; i < root.monitorGroups.length; ++i) {
            const current = root.monitorGroups[i];
            if (current.key === group.key)
                return y;
            y += root.groupHeight(current) + root.monitorSectionGap;
        }
        return y;
    }

    function entryLocalIndex(entryIndex) {
        const group = root.groupForEntry(entryIndex);
        return group ? entryIndex - group.start : entryIndex;
    }

    function entryLocalRow(entryIndex) {
        const group = root.groupForEntry(entryIndex);
        const localIndex = root.entryLocalIndex(entryIndex);
        return Math.floor(localIndex / root.groupColumns(group));
    }

    function entryLocalColumn(entryIndex) {
        const group = root.groupForEntry(entryIndex);
        const cols = root.groupColumns(group);
        const normalCol = root.entryLocalIndex(entryIndex) % cols;
        return Config.options.overview.orderRightLeft ? cols - normalCol - 1 : normalCol;
    }

    function entryX(entryIndex) {
        const group = root.groupForEntry(entryIndex);
        return root.groupX(group)
            + root.monitorSectionPaddingX
            + (root.workspaceImplicitWidth + root.workspaceSpacing) * root.entryLocalColumn(entryIndex);
    }

    function entryY(entryIndex) {
        const group = root.groupForEntry(entryIndex);
        return root.groupY(group)
            + root.monitorSectionPaddingTop
            + (root.groupWorkspaceHeight(group) + root.workspaceSpacing) * root.entryLocalRow(entryIndex);
    }

    function groupRowStart(group) {
        let row = root.getEntryRow(group.start);
        for (let i = group.start + 1; i <= group.end; ++i)
            row = Math.min(row, root.getEntryRow(i));
        return row;
    }

    function groupRowEnd(group) {
        let row = root.getEntryRow(group.start);
        for (let i = group.start + 1; i <= group.end; ++i)
            row = Math.max(row, root.getEntryRow(i));
        return row;
    }

    function groupColStart(group) {
        let col = root.getEntryColumn(group.start);
        for (let i = group.start + 1; i <= group.end; ++i)
            col = Math.min(col, root.getEntryColumn(i));
        return col;
    }

    function groupColEnd(group) {
        let col = root.getEntryColumn(group.start);
        for (let i = group.start + 1; i <= group.end; ++i)
            col = Math.max(col, root.getEntryColumn(i));
        return col;
    }

    function cycleOverviewWorkspace(dir) {
        WorkspaceNavigation.navigateByIndex(dir, false);
    }

    function dispatchFocusWorkspace(wsId) {
        WorkspaceNavigation.dispatchFocusWorkspace(wsId);
    }

    property color activeBorderColor: TuiStyle.controlActiveBorder

    property Component windowComponent: OverviewWindow {}
    property list<OverviewWindow> windowWidgets: []
    property var hoveredWindowData: null
    property var hoveredWorkspaceEntry: null

    function groupContainsWorkspaceId(group, workspaceId) {
        if (!group || !workspaceId)
            return false;
        for (let i = group.start; i <= group.end; ++i) {
            if (root.overviewEntries[i]?.id === workspaceId)
                return true;
        }
        return false;
    }

    function firstEntryForGroup(group) {
        if (!group)
            return null;
        return root.overviewEntries[group.start] ?? null;
    }

    function hoveredWorkspaceForGroup(group) {
        if (!root.hoveredWorkspaceEntry)
            return null;
        return root.hoveredWorkspaceEntry;
    }

    function hoveredWindowForGroup(group) {
        if (!root.hoveredWindowData)
            return null;
        return root.hoveredWindowData;
    }

    function defaultWindowForGroup(group) {
        if (OverviewSwitchingController.grabbed && GlobalStates.overviewFocusedWorkspaceId > 0) {
            return HyprlandData.focusedClientForWorkspace(GlobalStates.overviewFocusedWorkspaceId);
        }
        const entry = root.firstEntryForGroup(group);
        if (!entry || entry.isTrailingEmpty)
            return null;
        return HyprlandData.focusedClientForWorkspace(entry.id);
    }

    function infoEntryForGroup(group) {
        if (OverviewSwitchingController.grabbed && GlobalStates.overviewFocusedWorkspaceId > 0) {
            for (let i = group.start; i <= group.end; ++i) {
                if (root.overviewEntries[i]?.id === GlobalStates.overviewFocusedWorkspaceId)
                    return root.overviewEntries[i];
            }
        }
        return root.hoveredWorkspaceForGroup(group) ?? root.firstEntryForGroup(group);
    }

    function infoWindowForGroup(group) {
        const hoveredWindow = root.hoveredWindowForGroup(group);
        if (hoveredWindow)
            return hoveredWindow;
        if (root.hoveredWorkspaceForGroup(group))
            return null;
        return root.defaultWindowForGroup(group);
    }

    function showingWorkspaceInfoForGroup(group) {
        return root.hoveredWorkspaceForGroup(group) !== null || root.infoWindowForGroup(group) === null;
    }

    function infoTitleForGroup(group) {
        const win = root.infoWindowForGroup(group);
        if (win)
            return win.title || win.initialTitle || win.class || Translation.tr("No active window");

        const entry = root.infoEntryForGroup(group);
        if (!entry)
            return "";
        return entry.isTrailingEmpty
            ? Translation.tr("New workspace")
            : `${entry.monitorName || Translation.tr("Hidden")} · Workspace ${entry.id ?? ""}`;
    }

    function infoSubtitleForGroup(group) {
        const win = root.infoWindowForGroup(group);
        if (win)
            return win.class || "";

        const entry = root.infoEntryForGroup(group);
        if (!entry)
            return "";
        return entry.isTrailingEmpty
            ? Translation.tr("Create a workspace on this monitor")
            : Translation.tr("Workspace");
    }

    function infoIconSourceForGroup(group) {
        const win = root.infoWindowForGroup(group);
        return win ? AppSearch.iconSource(AppSearch.guessIcon(win.class || "")) : "";
    }

    Connections {
        target: GlobalStates
        function onOverviewFocusedWorkspaceIdChanged() {
            if (!OverviewSwitchingController.grabbed)
                return;
            root.hoveredWindowData = null;
            root.hoveredWorkspaceEntry = null;
        }
    }

    // ── Wheel scroll anywhere cycles workspaces ──
    MouseArea {
        anchors.fill: parent
        z: -1
        visible: true
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

    // Workspace grid — grouped by physical monitor in overview mode.
    Item {
        id: monitorGroupUnderlay
        anchors.fill: parent
        visible: root.monitorGroups.length > 0
        z: root.workspaceZ - 1

        // Subtle "Type to search" hint above the focused group
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.monitorGroups.length > 0 ? root.groupY(root.monitorGroups[0]) - 36 : 30
            z: 1000
            visible: !GlobalStates.overviewSearchMode && !OverviewSwitchingController.grabbed
            opacity: !GlobalStates.overviewSearchMode ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 7

                MaterialSymbol {
                    text: "search"
                    iconSize: 14
                    color: "#8f98a8"
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: Translation.tr("Type to search")
                    color: "#8f98a8"
                    font.pixelSize: 13
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Repeater {
            model: root.monitorGroups
            delegate: Rectangle {
                required property var modelData
                readonly property bool focusedGroup: modelData.key === (root.monitor?.name ?? "")

                x: root.groupX(modelData)
                y: root.groupY(modelData)
                width: root.groupWidth(modelData)
                height: root.groupHeight(modelData)
                radius: root.largeWorkspaceRadius + 12
                color: TuiStyle.bg
                border.width: focusedGroup ? 2 : 1
                border.color: focusedGroup
                    ? TuiStyle.controlActiveBorder
                    : ColorUtils.transparentize(Appearance.colors.colOutline, 0.35)

                StyledText {
                    anchors {
                        left: parent.left
                        top: parent.top
                        leftMargin: 14
                        topMargin: 8
                    }
                    text: modelData.label
                    color: parent.focusedGroup
                        ? TuiStyle.accent
                        : ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.18)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    width: parent.width - 28
                }
            }
        }
    }

    Item { // Workspaces
        id: workspaceColumnLayout

        z: root.workspaceZ
        anchors.fill: parent
        implicitWidth: root.overviewGridColumns * root.workspaceImplicitWidth
            + (root.overviewGridColumns - 1) * root.workspaceSpacing
        implicitHeight: root.overviewGridRows * root.workspaceImplicitHeight
            + (root.overviewGridRows - 1) * root.workspaceSpacing
        width: root.width
        height: root.height

            Repeater {
                model: root.overviewEntries
                delegate: Rectangle { // Workspace
                    id: workspace
                    required property var modelData
                    required property int index
                    property int workspaceValue: modelData.id
                    property string monitorName: modelData.monitorName ?? ""
                    property bool isTrailingEmpty: modelData.isTrailingEmpty ?? false
                    property bool isPendingOccupied: modelData.isPendingOccupied ?? false
                    property bool existingWorkspace: modelData.existingWorkspace ?? false
                    property int colIndex: root.entryLocalColumn(index)
                    property int rowIndex: root.entryLocalRow(index)
                    property color defaultWorkspaceColor: Appearance.colors.colSurfaceContainerLow
                    property color hoveredWorkspaceColor: ColorUtils.mix(defaultWorkspaceColor, Appearance.colors.colLayer1Hover, 0.1)
                    property color hoveredBorderColor: Appearance.colors.colLayer2Hover
                    property bool hoveredWhileDragging: false

                    x: root.entryX(index)
                    y: root.entryY(index)
                    width: root.entryWidth(index)
                    height: root.entryHeight(index)
                    color: hoveredWhileDragging ? hoveredWorkspaceColor : defaultWorkspaceColor
                    property bool workspaceAtLeft: colIndex === 0
                    property bool workspaceAtRight: {
                        const group = root.groupForEntry(index);
                        const cols = root.groupColumns(group);
                        return colIndex === cols - 1;
                    }
                    property bool workspaceAtTop: rowIndex === 0
                    property bool workspaceAtBottom: {
                        const group = root.groupForEntry(index);
                        const rows = root.groupRows(group);
                        return rowIndex === rows - 1;
                    }
                    topLeftRadius: root.largeWorkspaceRadius
                    topRightRadius: root.largeWorkspaceRadius
                    bottomLeftRadius: root.largeWorkspaceRadius
                    bottomRightRadius: root.largeWorkspaceRadius
                    border.width: 2
                    border.color: hoveredWhileDragging ? hoveredBorderColor : "transparent"
                    clip: true

                    // Wallpaper background for all workspaces (including trailing empty).
                    // In performance mode skip the per-workspace wallpaper Image
                    // (texture upload + sampling for every tile) and rely on the
                    // workspace rectangle's solid color instead.
                    Image {
                        anchors.fill: parent
                        source: FileUtils.expandHomePath(Config.options.background.wallpaperPath)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        mipmap: true
                        visible: !root.perfMode
                    }

                    StyledText {
                        anchors {
                            top: parent.top
                            left: parent.left
                            margins: 8
                        }
                        text: workspace.isTrailingEmpty
                            ? Translation.tr("New workspace")
                            : workspace.isPendingOccupied
                                ? Translation.tr("Moving…")
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
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        onEntered: {
                            if (!GlobalStates.overviewDraggingTargetWorkspace || GlobalStates.overviewDraggingTargetWorkspace === -1) {
                                root.hoveredWorkspaceEntry = workspace.modelData;
                                root.hoveredWindowData = null;
                            }
                        }
                        onExited: {
                            if (root.hoveredWorkspaceEntry?.id === workspace.workspaceValue)
                                root.hoveredWorkspaceEntry = null;
                        }
                        onPressed: {
                            if (GlobalStates.overviewDraggingTargetWorkspace === -1) {
                                if (workspace.isTrailingEmpty) {
                                    GlobalStates.overviewOpen = false;
                                    if (workspace.monitorName.length > 0)
                                        Hyprland.dispatch(`hl.dsp.focus({monitor="${workspace.monitorName}"})`);
                                    Hyprland.dispatch(`hl.dsp.focus({ workspace = ${workspace.workspaceValue} })`);
                                    if (!workspace.existingWorkspace && workspace.monitorName.length > 0)
                                        Hyprland.dispatch(`hl.dsp.workspace.move({ workspace = "${workspace.workspaceValue}", monitor = "${workspace.monitorName}" })`);
                                } else {
                                    if (HyprlandData.workspaceHasVisibleWindows(workspace.workspaceValue))
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
        anchors.fill: parent
        implicitWidth: workspaceColumnLayout.implicitWidth
        implicitHeight: workspaceColumnLayout.implicitHeight
        width: root.width
        height: root.height

            Repeater { // Window repeater
                model: ScriptModel {
                    values: {
                        // Register modelRevision as a dependency.
                        const _rev = root.modelRevision;
                        void _rev;
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
                    scaleX: {
                        const mon = window.monitor;
                        if (!mon)
                            return root.scale;
                        const width = (mon.transform & 1) ? mon.height : mon.width;
                        const reservedStart = mon.reserved?.[0] ?? 0;
                        const reservedEnd = mon.reserved?.[2] ?? 0;
                        const logicalWidth = Math.max(1, (width - reservedStart - reservedEnd) / (mon.scale ?? 1));
                        return root.entryWidth(workspaceEntryIndex) / logicalWidth;
                    }
                    scaleY: {
                        const mon = window.monitor;
                        if (!mon)
                            return root.scale;
                        const height = (mon.transform & 1) ? mon.width : mon.height;
                        const reservedStart = mon.reserved?.[1] ?? 0;
                        const reservedEnd = mon.reserved?.[3] ?? 0;
                        const logicalHeight = Math.max(1, (height - reservedStart - reservedEnd) / (mon.scale ?? 1));
                        return root.entryHeight(workspaceEntryIndex) / logicalHeight;
                    }
                    widgetMonitor: HyprlandData.monitors.find(m => m.id == root.monitor.id)
                    windowData: windowByAddress[address]

                    property bool atInitPosition: (initX == x && initY == y)

                    // Offset on the canvas
                    property int workspaceEntryIndex: root.indexForWorkspaceId(windowData?.workspace.id)
                    visible: workspaceEntryIndex >= 0 && !!windowData
                    xOffset: root.entryX(Math.max(0, workspaceEntryIndex))
                    yOffset: root.entryY(Math.max(0, workspaceEntryIndex))
                    workspaceWidth: root.entryWidth(Math.max(0, workspaceEntryIndex))
                    workspaceHeight: root.entryHeight(Math.max(0, workspaceEntryIndex))
                    property real xWithinWorkspaceWidget: window.localX
                    property real yWithinWorkspaceWidget: window.localY

                    // Radius
                    property real minRadius: Appearance.rounding.small
                    property bool workspaceAtLeft: true
                    property bool workspaceAtRight: true
                    property bool workspaceAtTop: true
                    property bool workspaceAtBottom: true
                    property bool workspaceAtTopLeft: true
                    property bool workspaceAtTopRight: true
                    property bool workspaceAtBottomLeft: true
                    property bool workspaceAtBottomRight: true 
                    property real distanceFromLeftEdge: xWithinWorkspaceWidget
                    property real distanceFromRightEdge: root.entryWidth(workspaceEntryIndex) - (xWithinWorkspaceWidget + targetWindowWidth)
                    property real distanceFromTopEdge: yWithinWorkspaceWidget
                    property real distanceFromBottomEdge: root.entryHeight(workspaceEntryIndex) - (yWithinWorkspaceWidget + targetWindowHeight)
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
                        onEntered: {
                            window.hovered = true
                            root.hoveredWindowData = windowData
                            root.hoveredWorkspaceEntry = null
                        }
                        onExited: {
                            window.hovered = false
                            if (root.hoveredWindowData?.address === windowData?.address)
                                root.hoveredWindowData = null
                        }
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
                                const percentageX = (window.x - xOffset) / root.entryWidth(workspaceEntryIndex)
                                const percentageY = (window.y - yOffset) / root.entryHeight(workspaceEntryIndex)
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
                    }
                }
            }

            Rectangle { // Focused workspace indicator
                id: focusedWorkspaceIndicator
                property int entryIndex: root.indexForWorkspaceId(root.highlightedWorkspaceId)
                visible: entryIndex >= 0
                x: root.entryX(Math.max(0, entryIndex))
                y: root.entryY(Math.max(0, entryIndex))
                z: root.windowZ
                width: root.entryWidth(Math.max(0, entryIndex))
                height: root.entryHeight(Math.max(0, entryIndex))
                color: "transparent"
                property bool workspaceAtLeft: true
                property bool workspaceAtRight: true
                property bool workspaceAtTop: true
                property bool workspaceAtBottom: true
                topLeftRadius: root.largeWorkspaceRadius
                topRightRadius: root.largeWorkspaceRadius
                bottomLeftRadius: root.largeWorkspaceRadius
                bottomRightRadius: root.largeWorkspaceRadius
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

    Repeater {
        model: root.localMonitorGroup ? [root.localMonitorGroup] : []

        delegate: Item {
            id: selectionInfoBar
            required property var modelData
            readonly property bool showingWorkspaceInfo: root.showingWorkspaceInfoForGroup(modelData)
            readonly property var infoEntry: root.infoEntryForGroup(modelData)
            readonly property string infoTitle: root.infoTitleForGroup(modelData)
            readonly property string infoSubtitle: root.infoSubtitleForGroup(modelData)
            readonly property string infoIconSource: root.infoIconSourceForGroup(modelData)
            readonly property real maxBarWidth: Math.min(620, Math.max(280, root.groupWidth(modelData) * 0.56))
            readonly property real targetWidth: Math.min(maxBarWidth, Math.max(96, infoRow.implicitWidth))
            readonly property real targetX: (root.width - targetWidth) / 2
            readonly property real targetY: {
                if (root.monitorGroups.length > 0) {
                    const lastGroup = root.monitorGroups[root.monitorGroups.length - 1];
                    return root.groupY(lastGroup) + root.groupHeight(lastGroup) + 20;
                }
                return root.height - height - 52;
            }

            x: Math.max(24, Math.min(root.width - width - 24, targetX))
            y: Math.max(24, Math.min(root.height - height - 24, targetY))
            z: root.windowDraggingZ + 1
            width: targetWidth
            height: 54
            visible: GlobalStates.overviewOpen && infoTitle.length > 0
            opacity: visible ? 1 : 0

            Behavior on x { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
            Behavior on y { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
            }

            RowLayout {
                id: infoRow
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 16
                spacing: 12

                Item {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignVCenter

                    StyledImage {
                        anchors.fill: parent
                        visible: !selectionInfoBar.showingWorkspaceInfo && selectionInfoBar.infoIconSource.length > 0
                        source: selectionInfoBar.infoIconSource
                        mipmap: true
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: selectionInfoBar.showingWorkspaceInfo || selectionInfoBar.infoIconSource.length === 0
                        text: selectionInfoBar.showingWorkspaceInfo
                            ? (selectionInfoBar.infoEntry?.isTrailingEmpty ? "add" : "select_window")
                            : "apps"
                        iconSize: 26
                        color: selectionInfoBar.showingWorkspaceInfo && selectionInfoBar.infoEntry?.isTrailingEmpty
                            ? TuiStyle.accent
                            : Appearance.colors.colOnLayer1
                    }
                }

                ColumnLayout {
                    Layout.maximumWidth: selectionInfoBar.maxBarWidth - 42
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1

                    StyledText {
                        Layout.preferredWidth: Math.min(implicitWidth, selectionInfoBar.maxBarWidth - 42)
                        text: selectionInfoBar.infoTitle
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    StyledText {
                        Layout.preferredWidth: Math.min(implicitWidth, selectionInfoBar.maxBarWidth - 42)
                        visible: selectionInfoBar.infoSubtitle.length > 0
                        text: selectionInfoBar.infoSubtitle
                        color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.36)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }
        }
    }
    }
