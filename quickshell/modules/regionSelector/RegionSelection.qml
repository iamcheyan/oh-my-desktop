pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.utils
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import Qt.labs.synchronizer
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: root
    visible: false
    color: "transparent"
    WlrLayershell.namespace: "quickshell:regionSelector"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    // Modes
    // TODO: Ask: sidebar AI
    enum SnipAction { Copy, Edit, Search, CharRecognition, Record, RecordWithSound } 
    enum SelectionMode { RectCorners, Circle }
    enum Phase { Select, Post }
    property var action: RegionSelection.SnipAction.Copy
    property var selectionMode: RegionSelection.SelectionMode.RectCorners
    property var phase: RegionSelection.Phase.Select
    property bool captureReady: false
    signal dismiss()

    // Styles
    property string screenshotDir: Directories.screenshotTemp
    property color overlayColor: ColorUtils.transparentize("#000000", 0.5)
    // Keep screenshot selection neutral. Theme accent colors can be bright
    // green; using them here makes the capture mask visually distracting.
    property color brightText: "#f4f4f4"
    property color brightSecondary: "#b8b8b8"
    property color brightTertiary: "#8f8f8f"
    property color selectionBorderColor: "#e5e5e5"
    property color selectionFillColor: "#22ffffff"
    property color windowBorderColor: brightSecondary
    property color windowFillColor: "#18ffffff"
    property color imageBorderColor: brightTertiary
    property color imageFillColor: "#14ffffff"
    property color onBorderColor: "#ff000000"
    property real targetRegionOpacity: Config.options.regionSelector.targetRegions.opacity
    property bool contentRegionOpacity: Config.options.regionSelector.targetRegions.contentRegionOpacity

    // Vars for indicators
    readonly property var windows: [...HyprlandData.windowList].sort((a, b) => {
        // Sort floating=true windows before others
        if (a.floating === b.floating) return 0;
        return a.floating ? -1 : 1;
    })
    readonly property var layers: HyprlandData.layers
    readonly property real falsePositivePreventionRatio: 0.5

    // Screen & interaction vars
    readonly property HyprlandMonitor hyprlandMonitor: Hyprland.monitorFor(screen)
    readonly property real monitorScale: hyprlandMonitor?.scale ?? 1
    readonly property real monitorOffsetX: hyprlandMonitor?.x ?? 0
    readonly property real monitorOffsetY: hyprlandMonitor?.y ?? 0
    property int activeWorkspaceId: hyprlandMonitor?.activeWorkspace?.id ?? 0
    property string screenshotPath: `${root.screenshotDir}/image-${screen.name}-${Date.now()}.png`
    // True when screenshotPath points to a pre-captured file (created by the
    // shell script). We must not delete it on destruction since other monitor
    // instances may still reference it.
    property bool preCapSnapshot: false
    // When true, send `menus close` to the bar immediately after the overlay
    // becomes visible. This ensures the overlay covers the screen BEFORE the
    // live menus are dismissed, preventing the user from seeing a frame where
    // the menus have disappeared but the frozen snapshot has not yet appeared.
    property bool closeMenusOnShow: false
    property bool snapshotReady: false
    property string savedScreenshotPath: ""
    property string tempScreenshotPath: ""
    property bool postCaptureReady: false
    property real dragStartX: 0
    property real dragStartY: 0
    property real draggingX: 0
    property real draggingY: 0
    property real dragDiffX: 0
    property real dragDiffY: 0
    property bool draggedAway: (dragDiffX !== 0 || dragDiffY !== 0)
    property bool dragging: false
    property list<point> points: []
    property var mouseButton: null
    property var imageRegions: []
    readonly property list<var> windowRegions: {
        if (!root.hyprlandMonitor) return [];
        return RegionFunctions.filterWindowRegionsByLayers(
            root.windows.filter(w => w.workspace?.id === root.activeWorkspaceId),
            root.layerRegions
        ).map(window => {
            return {
                at: [window.at[0] - root.monitorOffsetX, window.at[1] - root.monitorOffsetY],
                size: [window.size[0], window.size[1]],
                class: window.class,
                title: window.title,
            }
        });
    }
    readonly property list<var> layerRegions: {
        if (!root.hyprlandMonitor) return [];
        const layersOfThisMonitor = root.layers[root.hyprlandMonitor.name]
        const topLayers = layersOfThisMonitor?.levels["2"]
        if (!topLayers) return [];
        const nonBarTopLayers = topLayers
            .filter(layer => !(layer.namespace.includes(":bar") || layer.namespace.includes(":verticalBar") || layer.namespace.includes(":dock")))
            .map(layer => {
            return {
                at: [layer.x, layer.y],
                size: [layer.w, layer.h],
                namespace: layer.namespace,
            }
        })
        const offsetAdjustedLayers = nonBarTopLayers.map(layer => {
            return {
                at: [layer.at[0] - root.monitorOffsetX, layer.at[1] - root.monitorOffsetY],
                size: layer.size,
                namespace: layer.namespace,
            }
        });
        return offsetAdjustedLayers;
    }

    // Config
    property bool isCircleSelection: (root.selectionMode === RegionSelection.SelectionMode.Circle)
    // Window click-to-select must stay enabled; content regions need OpenCV which we removed.
    property bool enableWindowRegions: Config.options.regionSelector.targetRegions.windows && !isCircleSelection
    property bool enableLayerRegions: Config.options.regionSelector.targetRegions.layers && !isCircleSelection
    property bool enableContentRegions: false

    function scaledSnapshotCoord(value) {
        return value * root.monitorScale;
    }

    // Target
    property real targetedRegionX: -1
    property real targetedRegionY: -1
    property real targetedRegionWidth: 0
    property real targetedRegionHeight: 0
    function targetedRegionValid() {
        return (root.targetedRegionX >= 0 && root.targetedRegionY >= 0)
    }
    function setRegionToTargeted() {
        const padding = Config.options.regionSelector.targetRegions.selectionPadding; // Make borders not cut off n stuff
        root.regionX = root.targetedRegionX - padding;
        root.regionY = root.targetedRegionY - padding;
        root.regionWidth = root.targetedRegionWidth + padding * 2;
        root.regionHeight = root.targetedRegionHeight + padding * 2;
    }

    function updateTargetedRegion(x, y) {
        // Image regions
        const clickedRegion = root.imageRegions.find(region => {
            return region.at[0] <= x && x <= region.at[0] + region.size[0] && region.at[1] <= y && y <= region.at[1] + region.size[1];
        });
        if (clickedRegion) {
            root.targetedRegionX = clickedRegion.at[0];
            root.targetedRegionY = clickedRegion.at[1];
            root.targetedRegionWidth = clickedRegion.size[0];
            root.targetedRegionHeight = clickedRegion.size[1];
            return;
        }

        // Layer regions
        const clickedLayer = root.layerRegions.find(region => {
            return region.at[0] <= x && x <= region.at[0] + region.size[0] && region.at[1] <= y && y <= region.at[1] + region.size[1];
        });
        if (clickedLayer) {
            root.targetedRegionX = clickedLayer.at[0];
            root.targetedRegionY = clickedLayer.at[1];
            root.targetedRegionWidth = clickedLayer.size[0];
            root.targetedRegionHeight = clickedLayer.size[1];
            return;
        }

        // Window regions
        const clickedWindow = root.windowRegions.find(region => {
            return region.at[0] <= x && x <= region.at[0] + region.size[0] && region.at[1] <= y && y <= region.at[1] + region.size[1];
        });
        if (clickedWindow) {
            root.targetedRegionX = clickedWindow.at[0];
            root.targetedRegionY = clickedWindow.at[1];
            root.targetedRegionWidth = clickedWindow.size[0];
            root.targetedRegionHeight = clickedWindow.size[1];
            return;
        }

        root.targetedRegionX = -1;
        root.targetedRegionY = -1;
        root.targetedRegionWidth = 0;
        root.targetedRegionHeight = 0;
    }

    property bool shiftPressed: false

    property real regionWidth: {
        const dx = draggingX - dragStartX;
        const dy = draggingY - dragStartY;
        if (shiftPressed) {
            return Math.max(Math.abs(dx), Math.abs(dy));
        }
        return Math.abs(dx);
    }
    property real regionHeight: {
        const dx = draggingX - dragStartX;
        const dy = draggingY - dragStartY;
        if (shiftPressed) {
            return Math.max(Math.abs(dx), Math.abs(dy));
        }
        return Math.abs(dy);
    }
    property real regionX: {
        const dx = draggingX - dragStartX;
        if (shiftPressed) {
            const size = regionWidth;
            return dx >= 0 ? dragStartX : dragStartX - size;
        }
        return Math.min(dragStartX, draggingX);
    }
    property real regionY: {
        const dy = draggingY - dragStartY;
        if (shiftPressed) {
            const size = regionHeight;
            return dy >= 0 ? dragStartY : dragStartY - size;
        }
        return Math.min(dragStartY, draggingY);
    }

    property bool isRecording: root.action === RegionSelection.SnipAction.Record || root.action === RegionSelection.SnipAction.RecordWithSound
    property bool recordingShouldStop: false
    Process {
        id: checkRecordingProc
        running: isRecording
        command: ["pidof", "wf-recorder"]
        onExited: (exitCode, exitStatus) => {
            root.recordingShouldStop = (exitCode === 0);
            root.preparationDone = true;
        }
    }
    property bool preparationDone: false
    Component.onCompleted: {
        if (!isRecording) {
            preparationDone = true;
        }
    }
    Component.onDestruction: {
        // Only delete the snapshot if we created it ourselves (snapshotProc).
        // Pre-captured snapshots (preCapSnapshot=true) were created by the
        // shell script and should not be removed here.
        if (!root.preCapSnapshot && root.screenshotPath !== "") {
            Quickshell.execDetached(["rm", "-f", root.screenshotPath]);
        }
    }
    onPreparationDoneChanged: {
        if (!preparationDone) return;
        if (root.isRecording && root.recordingShouldStop) {
            Quickshell.execDetached([Directories.recordScriptPath]);
            root.dismiss();
            return;
        }
        if (root.isRecording) {
            // Recording captures the live compositor output, so hide bar
            // overlays before showing the selector.
            const barDir = (Quickshell.env("OMD_REPO_ROOT") ?? "") + "/apps/omd-bar";
            Quickshell.execDetached([
                "qs", "-p", barDir,
                "ipc", "call", "menus", "close"
            ]);
            root.visible = true;
            root.captureReady = true;
        } else {
            // Try to use a pre-captured snapshot from the shell script.
            // The shell exports OMD_SNAPSHOT_PATH_<MONITOR_ENV> where monitor
            // name dashes/dots become underscores (e.g. HDMI-A-1 → HDMI_A_1).
            const snapshotDir = Quickshell.env("OMD_SNAPSHOT_DIR") ?? "";
            const monitorName = root.screen?.name ?? "";
            const monEnv = monitorName.replace(/[-\.]/g, "_");
            const preCapPath = Quickshell.env(`OMD_SNAPSHOT_PATH_${monEnv}`) ?? "";
            if (preCapPath !== "") {
                // Pre-captured snapshot exists — use it directly.
                root.screenshotPath = preCapPath;
                root.preCapSnapshot = true;
                root.snapshotReady = true;
                // Defer menus close until AFTER the overlay becomes visible
                // (handled in showSnapshotTimer.onTriggered).
                root.closeMenusOnShow = true;
                showSnapshotTimer.restart();
            } else {
                // No pre-captured snapshot; fall back to capturing now.
                snapshotProc.running = true;
            }
        }
    }

    Timer {
        id: showSnapshotTimer
        interval: 60
        repeat: false
        onTriggered: {
            root.visible = true;
            root.captureReady = true;
            // Send menus close AFTER the overlay is visible so the user never
            // sees a frame where live menus are gone but the snapshot hasn't
            // appeared yet.
            if (root.closeMenusOnShow) {
                root.closeMenusOnShow = false;
                const barDir = (Quickshell.env("OMD_REPO_ROOT") ?? "") + "/apps/omd-bar";
                Quickshell.execDetached([
                    "qs", "-p", barDir,
                    "ipc", "call", "menus", "close"
                ]);
            }
        }
    }

    Process {
        id: snapshotProc
        running: false
        command: ["bash", "-c",
            `mkdir -p ${ScreenshotAction.quote(root.screenshotDir)} && grim -o ${ScreenshotAction.quote(root.screen.name)} ${ScreenshotAction.quote(root.screenshotPath)}`
        ]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.snapshotReady = true;
                // Defer menus close until AFTER the overlay becomes visible
                // (handled in showSnapshotTimer.onTriggered).
                root.closeMenusOnShow = true;
                showSnapshotTimer.restart();
            } else {
                console.warn(`[Region Selector] Snapshot capture failed with exit code ${exitCode}.`);
                root.dismiss();
            }
        }
    }

    function getScreenshotAction() {
        switch(root.action) {
            case RegionSelection.SnipAction.Copy:
                return ScreenshotAction.Action.Copy;
            case RegionSelection.SnipAction.Edit:
                return ScreenshotAction.Action.Edit;
            case RegionSelection.SnipAction.Search:
                return ScreenshotAction.Action.Search;
            case RegionSelection.SnipAction.CharRecognition:
                return ScreenshotAction.Action.CharRecognition;
            case RegionSelection.SnipAction.Record:
                return ScreenshotAction.Action.Record;
            case RegionSelection.SnipAction.RecordWithSound:
                return ScreenshotAction.Action.RecordWithSound;
            default:
                console.warn("[Region Selector] Unknown snip action, skipping snip.");
                root.dismiss();
                return;
        }
    }

    Timer {
        id: snipDelayTimer
        interval: 100
        repeat: false
        onTriggered: {
            const saveDir = Config.options.screenSnip.savePath !== "" ? Config.options.screenSnip.savePath : "";
            var screenshotAction = root.getScreenshotAction();

            if (root.action === RegionSelection.SnipAction.Edit) {
                root.tempScreenshotPath = `/tmp/omd-screenshot-${Date.now()}.png`;
                root.postCaptureReady = false;
                postCaptureProc.command = ScreenshotAction.getSnapshotCropCommand(
                    root.scaledSnapshotCoord(root.regionX),
                    root.scaledSnapshotCoord(root.regionY),
                    root.scaledSnapshotCoord(root.regionWidth),
                    root.scaledSnapshotCoord(root.regionHeight),
                    root.screenshotPath,
                    root.tempScreenshotPath
                );
                postCaptureProc.running = true;
                root.phase = RegionSelection.Phase.Post;
                root.visible = true;
                return;
            }

            const command = root.isRecording
                ? ScreenshotAction.getRegionCommand(
                    root.regionX + root.monitorOffsetX,
                    root.regionY + root.monitorOffsetY,
                    root.regionWidth,
                    root.regionHeight,
                    screenshotAction,
                    saveDir
                )
                : ScreenshotAction.getCommand(
                    root.scaledSnapshotCoord(root.regionX),
                    root.scaledSnapshotCoord(root.regionY),
                    root.scaledSnapshotCoord(root.regionWidth),
                    root.scaledSnapshotCoord(root.regionHeight),
                    root.screenshotPath,
                    screenshotAction,
                    saveDir
                );
            Quickshell.execDetached(command);
            if (root.action == RegionSelection.SnipAction.Record || root.action == RegionSelection.SnipAction.RecordWithSound) {
                root.phase = RegionSelection.Phase.Post
                root.selectionMode = RegionSelection.SelectionMode.RectCorners
            } else {
                root.dismiss();
            }
        }
    }

    Process {
        id: postCaptureProc
        running: false
        command: []
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.postCaptureReady = true;
            } else {
                console.warn(`[Region Selector] Post-capture failed with exit code ${exitCode}.`);
                root.dismiss();
            }
        }
    }

    // Execution after selection
    function snip() {
        if (!root.snapshotReady && !root.isRecording) {
            console.warn("[Region Selector] Snapshot is not ready, skipping snip.");
            return;
        }

        // Validity check
        if (root.regionWidth <= 0 || root.regionHeight <= 0) {
            console.warn("[Region Selector] Invalid region size, skipping snip.");
            root.dismiss();
            return;
        }

        // Clamp region to screen bounds
        root.regionX = Math.max(0, Math.min(root.regionX, root.screen.width - root.regionWidth));
        root.regionY = Math.max(0, Math.min(root.regionY, root.screen.height - root.regionHeight));
        root.regionWidth = Math.max(0, Math.min(root.regionWidth, root.screen.width - root.regionX));
        root.regionHeight = Math.max(0, Math.min(root.regionHeight, root.screen.height - root.regionY));

        // Adjust action
        if (root.action === RegionSelection.SnipAction.Copy) {
            root.action = root.mouseButton === Qt.RightButton ? RegionSelection.SnipAction.Edit : RegionSelection.SnipAction.Copy;
        }

        // Recording still captures the live compositor output, so hide the overlay first.
        if (root.isRecording) {
            root.visible = false;
        }
        snipDelayTimer.start();
    }

    // Only clickable in Selection phase
    mask: Region {
        item: root.phase === RegionSelection.Phase.Select ? mouseArea : actionBarMask
    }

    Image {
        id: frozenSnapshot
        anchors.fill: parent
        cache: false
        fillMode: Image.Stretch
        source: root.snapshotReady ? Qt.resolvedUrl(`file://${root.screenshotPath}`) : ""
        visible: root.visible
    }

    Item {
        anchors.fill: parent
        visible: root.visible
        focus: root.visible
        Keys.onPressed: (event) => { // Esc to close
            if (event.key === Qt.Key_Escape) {
                root.dismiss();
            } else if (event.key === Qt.Key_Shift) {
                root.shiftPressed = true;
            }
        }
        Keys.onReleased: (event) => {
            if (event.key === Qt.Key_Shift) {
                root.shiftPressed = false;
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: root.phase === RegionSelection.Phase.Select ? Qt.BlankCursor : Qt.ArrowCursor
        acceptedButtons: root.phase === RegionSelection.Phase.Select ? Qt.LeftButton | Qt.RightButton : Qt.NoButton
        hoverEnabled: root.phase === RegionSelection.Phase.Select

        // Controls
        onPressed: (mouse) => {
            if (!root.snapshotReady && !root.isRecording) {
                mouse.accepted = true;
                return;
            }
            root.shiftPressed = (mouse.modifiers & Qt.ShiftModifier) !== 0;
            root.dragStartX = mouse.x;
            root.dragStartY = mouse.y;
            root.draggingX = mouse.x;
            root.draggingY = mouse.y;
            root.dragging = true;
            root.mouseButton = mouse.button;
        }
        onReleased: (mouse) => {
            if (!root.dragging) {
                mouse.accepted = true;
                return;
            }
            root.shiftPressed = (mouse.modifiers & Qt.ShiftModifier) !== 0;
            // Detect if it was a click -> Try to select targeted region
            if (root.draggingX === root.dragStartX && root.draggingY === root.dragStartY) {
                if (root.targetedRegionValid()) {
                    root.setRegionToTargeted();
                } else {
                    // Empty click (no window target): keep overlay open instead of
                    // treating it as a zero-size capture that immediately dismisses.
                    root.dragging = false;
                    return;
                }
            }
            // Circle dragging?
            else if (root.selectionMode === RegionSelection.SelectionMode.Circle) {
                const padding = Config.options.regionSelector.circle.padding + Config.options.regionSelector.circle.strokeWidth / 2;
                const dragPoints = (root.points.length > 0) ? root.points : [{ x: mouseArea.mouseX, y: mouseArea.mouseY }];
                const maxX = Math.max(...dragPoints.map(p => p.x));
                const minX = Math.min(...dragPoints.map(p => p.x));
                const maxY = Math.max(...dragPoints.map(p => p.y));
                const minY = Math.min(...dragPoints.map(p => p.y));
                root.regionX = minX - padding;
                root.regionY = minY - padding;
                root.regionWidth = maxX - minX + padding * 2;
                root.regionHeight = maxY - minY + padding * 2;
            }
            root.snip();
        }
        onPositionChanged: (mouse) => {
            root.shiftPressed = (mouse.modifiers & Qt.ShiftModifier) !== 0;
            if (!root.dragging) {
                root.updateTargetedRegion(mouse.x, mouse.y);
                return;
            }
            root.draggingX = mouse.x;
            root.draggingY = mouse.y;
            root.dragDiffX = mouse.x - root.dragStartX;
            root.dragDiffY = mouse.y - root.dragStartY;
            if (root.selectionMode === RegionSelection.SelectionMode.Circle) {
                root.points.push({ x: mouse.x, y: mouse.y });
            }
        }
        
        Loader {
            z: 2
            anchors.fill: parent
            active: root.selectionMode === RegionSelection.SelectionMode.RectCorners
            sourceComponent: RectCornersSelectionDetails {
                regionX: root.regionX
                regionY: root.regionY
                regionWidth: root.regionWidth
                regionHeight: root.regionHeight
                mouseX: root.dragging
                    ? (root.draggingX >= root.dragStartX ? root.regionX + root.regionWidth : root.regionX)
                    : mouseArea.mouseX
                mouseY: root.dragging
                    ? (root.draggingY >= root.dragStartY ? root.regionY + root.regionHeight : root.regionY)
                    : mouseArea.mouseY
                color: root.selectionBorderColor
                overlayColor: root.overlayColor
                breathingBorderOnly: false
                captureReady: root.captureReady
            }
        }

        Loader {
            z: 2
            anchors.fill: parent
            active: root.selectionMode === RegionSelection.SelectionMode.Circle
            sourceComponent: CircleSelectionDetails {
                color: root.selectionBorderColor
                overlayColor: root.overlayColor
                points: root.points
            }
        }

        CursorGuide {
            z: 9999
            visible: root.phase === RegionSelection.Phase.Select && root.dragging
            x: root.regionX + root.regionWidth - width / 2
            y: root.regionY + root.regionHeight - height / 2
            action: root.action
            selectionMode: root.selectionMode
        }

        // Window regions
        Repeater {
            model: ScriptModel {
                values: {
                    if (root.phase === RegionSelection.Phase.Select && root.enableWindowRegions) {
                        return root.windowRegions
                    } else {
                        return []
                    }
                }
            }
            delegate: TargetRegion {
                z: 2
                required property var modelData
                clientDimensions: modelData
                showIcon: true
                targeted: !root.draggedAway && //
                    (root.targetedRegionX === modelData.at[0]  //
                    && root.targetedRegionY === modelData.at[1] //
                    && root.targetedRegionWidth === modelData.size[0] //
                    && root.targetedRegionHeight === modelData.size[1])

                opacity: root.draggedAway ? 0 : root.targetRegionOpacity
                borderColor: root.windowBorderColor
                fillColor: targeted ? root.windowFillColor : "transparent"
                text: `${modelData.class}`
                radius: Appearance.rounding.windowRounding
            }
        }

        // Layer regions
        Repeater {
            model: ScriptModel {
                values: {
                    if (root.phase === RegionSelection.Phase.Select && root.enableLayerRegions) {
                        return root.layerRegions
                    } else {
                        return []
                    }
                }
            }
            delegate: TargetRegion {
                z: 3
                required property var modelData
                clientDimensions: modelData
                targeted: !root.draggedAway &&
                    (root.targetedRegionX === modelData.at[0] 
                    && root.targetedRegionY === modelData.at[1]
                    && root.targetedRegionWidth === modelData.size[0]
                    && root.targetedRegionHeight === modelData.size[1])

                opacity: root.draggedAway ? 0 : root.targetRegionOpacity
                borderColor: root.windowBorderColor
                fillColor: targeted ? root.windowFillColor : "transparent"
                text: `${modelData.namespace}`
                radius: Appearance.rounding.windowRounding
            }
        }

        // Content regions
        Repeater {
            model: ScriptModel {
                values: {
                    if (root.phase === RegionSelection.Phase.Select && root.enableContentRegions) {
                        return root.imageRegions
                    } else {
                        return []
                    }
                }
            }
            delegate: TargetRegion {
                z: 4
                required property var modelData
                clientDimensions: modelData
                targeted: !root.draggedAway &&
                    (root.targetedRegionX === modelData.at[0] 
                    && root.targetedRegionY === modelData.at[1]
                    && root.targetedRegionWidth === modelData.size[0]
                    && root.targetedRegionHeight === modelData.size[1])

                opacity: root.draggedAway ? 0 : root.contentRegionOpacity
                borderColor: root.imageBorderColor
                fillColor: targeted ? root.imageFillColor : "transparent"
                text: "Content region"
            }
        }


    }

    // Post-phase full-screen capture + action bar
    Item {
        id: actionBarMask
        visible: root.phase === RegionSelection.Phase.Post
        anchors.fill: parent
        focus: true

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                root.dismiss();
            }
        }

        // Full-screen mouse capture: click outside buttons = dismiss
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.ArrowCursor
            onClicked: root.dismiss()
        }

        // Action bar (on top, buttons intercept clicks)
        Item {
            x: {
                const rightEdge = root.regionX + root.regionWidth;
                const barW = width;
                const clampedX = Math.max(0, rightEdge - barW);
                return Math.min(clampedX, root.width - barW);
            }
            y: {
                const barH = height;
                const yBelow = root.regionY + root.regionHeight + 12;
                if (yBelow + barH > root.height)
                    return Math.max(0, root.regionY - 12 - barH);
                return yBelow;
            }
            width: actionBar.implicitWidth
            height: actionBar.implicitHeight

            Row {
                id: actionBar
                spacing: 8
                enabled: root.postCaptureReady
                opacity: root.postCaptureReady ? 1 : 0.45

                Rectangle {
                    id: copyButton
                    width: 40; height: 40; radius: 8
                    color: copyMouse.containsMouse ? TuiStyle.controlHover : TuiStyle.control
                    border.width: 1
                    border.color: copyMouse.containsMouse ? TuiStyle.controlActiveBorder : TuiStyle.menuBorder

                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: 22
                        color: copyMouse.containsMouse ? TuiStyle.accent : TuiStyle.fg
                        text: "content_copy"
                    }

                    MouseArea {
                        id: copyMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(ScreenshotAction.getTempFileCommand(
                                root.tempScreenshotPath,
                                ScreenshotAction.Action.Copy,
                                ""
                            ));
                            root.dismiss();
                        }
                    }
                }

                Rectangle {
                    id: saveButton
                    width: 40; height: 40; radius: 8
                    color: saveMouse.containsMouse ? TuiStyle.controlHover : TuiStyle.control
                    border.width: 1
                    border.color: saveMouse.containsMouse ? TuiStyle.controlActiveBorder : TuiStyle.menuBorder

                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: 22
                        color: saveMouse.containsMouse ? TuiStyle.accent : TuiStyle.fg
                        text: "save"
                    }

                    MouseArea {
                        id: saveMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const saveDir = Config.options.screenSnip.savePath !== "" ? Config.options.screenSnip.savePath : "";
                            Quickshell.execDetached(ScreenshotAction.getTempFileCommand(
                                root.tempScreenshotPath,
                                ScreenshotAction.Action.Copy,
                                saveDir
                            ));
                            root.dismiss();
                        }
                    }
                }

                Rectangle {
                    id: searchButton
                    width: 40; height: 40; radius: 8
                    color: searchMouse.containsMouse ? TuiStyle.controlHover : TuiStyle.control
                    border.width: 1
                    border.color: searchMouse.containsMouse ? TuiStyle.controlActiveBorder : TuiStyle.menuBorder

                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: 22
                        color: searchMouse.containsMouse ? TuiStyle.accent : TuiStyle.fg
                        text: "image_search"
                    }

                    MouseArea {
                        id: searchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(ScreenshotAction.getTempFileCommand(
                                root.tempScreenshotPath,
                                ScreenshotAction.Action.Search
                            ));
                            root.dismiss();
                        }
                    }
                }

                Rectangle {
                    id: ocrButton
                    width: 40; height: 40; radius: 8
                    color: ocrMouse.containsMouse ? TuiStyle.controlHover : TuiStyle.control
                    border.width: 1
                    border.color: ocrMouse.containsMouse ? TuiStyle.controlActiveBorder : TuiStyle.menuBorder

                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: 22
                        color: ocrMouse.containsMouse ? TuiStyle.accent : TuiStyle.fg
                        text: "text_snippet"
                    }

                    MouseArea {
                        id: ocrMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(ScreenshotAction.getTempFileCommand(
                                root.tempScreenshotPath,
                                ScreenshotAction.Action.CharRecognition
                            ));
                            root.dismiss();
                        }
                    }
                }

                Rectangle {
                    id: editButton
                    width: 40; height: 40; radius: 8
                    color: editMouse.containsMouse ? TuiStyle.controlHover : TuiStyle.control
                    border.width: 1
                    border.color: editMouse.containsMouse ? TuiStyle.controlActiveBorder : TuiStyle.menuBorder

                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: 22
                        color: editMouse.containsMouse ? TuiStyle.accent : TuiStyle.fg
                        text: "edit"
                    }

                    MouseArea {
                        id: editMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(ScreenshotAction.getTempFileCommand(
                                root.tempScreenshotPath,
                                ScreenshotAction.Action.Edit
                            ));
                            root.dismiss();
                        }
                    }
                }
            }
        }
    }
}
