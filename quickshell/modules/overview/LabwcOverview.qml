import qs
import qs.services
import qs.core.runtime
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

/// labwc 分支的 overview：全新简化实现。
///
/// Hyprland 版 Overview/OverviewWidget 深度绑定 Quickshell.Hyprland
/// （HyprlandMonitor / ToplevelManager / ServiceManager.workspace /
/// ScreencopyView），labwc 下无对应数据源。本组件自 thumbnaild
/// （LabwcOverviewBridge）取窗口枚举 + grim 抓帧的 PNG 缩略图，
/// 提供：当前工作区窗口缩略图网格、工作区条（点击切换）、
/// 标题/应用搜索过滤、点击缩略图聚焦窗口（zwlr activate）。
///
/// 与 Hyprland 版保持同一 IPC 接口（IpcHandler "overview"），
/// bar 按钮 `overview.toggle` / `overview.open` 行为不变。
/// 不注册 GlobalShortcut：labwc 快捷键由 rc.xml 管理。
Scope {
    id: overviewScope

    property bool open: false
    property string filterQuery: ""
    property int selectedIndex: 0
    property bool searchFocused: false
    /// W-Tab 按住循环模式：网格显示全部工作区窗口，释放后自动提交
    property bool cycleMode: false
    /// 调试：最近一次事件（用于 IPC 查询定位点击问题）
    property string dbgLastEvent: "(none)"
    /// 右键窗口菜单：0=关闭 1=动作选择 2=工作区选择
    property int menuStage: 0
    /// 右键菜单目标窗口 + 已选动作（"silent" | "follow"）
    property string menuTargetId: ""
    property string menuTargetTitle: ""
    property string menuTargetWorkspace: ""
    property string menuAction: ""
    /// 菜单左上角坐标（相对 panelWindow 内容区）
    property int menuX: 0
    property int menuY: 0

    readonly property var bridge: LabwcOverviewBridge

    /// 循环模式用全部窗口（跨工作区，忽略搜索过滤），Hyprland mod+TAB 语义
    readonly property var cycleWindows: bridge.windows ?? []
    /// 网格实际显示：循环模式 → 全部窗口；普通打开 → 当前工作区（可过滤）
    readonly property var displayWindows: cycleMode ? cycleWindows : visibleWindows

    /// 当前工作区窗口（含归属未知的，即 workspace == "" 或 == active）
    readonly property var visibleWindows: {
        const active = bridge.activeWorkspace;
        const q = filterQuery.trim().toLowerCase();
        const out = [];
        const wins = bridge.windows ?? [];
        for (let i = 0; i < wins.length; ++i) {
            const w = wins[i];
            const onActive = w.workspace === "" || w.workspace === active;
            if (!onActive)
                continue;
            if (q.length > 0
                && (w.title ?? "").toLowerCase().indexOf(q) < 0
                && (w.app_id ?? "").toLowerCase().indexOf(q) < 0)
                continue;
            out.push(w);
        }
        return out;
    }

    readonly property int gridColumns: Math.max(2, Math.min(6,
        Math.floor((panelWindow.width - 96) / 300)))

    function closeOverview() {
        overviewScope.open = false;
        overviewScope.cycleMode = false;
        overviewScope.filterQuery = "";
        overviewScope.selectedIndex = 0;
        overviewScope.searchFocused = false;
        overviewScope.menuStage = 0;
        overviewScope.menuTargetId = "";
    }

    function clampSelection() {
        const n = overviewScope.visibleWindows.length;
        if (n === 0) {
            overviewScope.selectedIndex = 0;
            return;
        }
        overviewScope.selectedIndex = Math.max(0,
            Math.min(overviewScope.selectedIndex, n - 1));
    }

    function moveSelection(dx, dy) {
        const n = overviewScope.visibleWindows.length;
        if (n === 0)
            return;
        const cols = overviewScope.gridColumns;
        let idx = overviewScope.selectedIndex;
        if (dx !== 0) {
            const row = Math.floor(idx / cols);
            const col = idx % cols;
            let nc = col + dx;
            if (nc < 0)
                nc = cols - 1;
            if (nc >= cols)
                nc = 0;
            idx = row * cols + nc;
        } else if (dy !== 0) {
            idx = idx + dy * cols;
        }
        idx = Math.max(0, Math.min(idx, n - 1));
        overviewScope.selectedIndex = idx;
    }

    function activateSelected() {
        const wins = overviewScope.displayWindows;
        if (overviewScope.selectedIndex >= 0 && overviewScope.selectedIndex < wins.length) {
            const w = wins[overviewScope.selectedIndex];
            bridge.activateWindow(w.identifier);
            overviewScope.closeOverview();
        }
    }

    /// 打开窗口右键菜单（stage 1：动作选择）。x/y 为相对 panelWindow 的
    /// 鼠标位置；菜单尺寸随 stage 变化，钳制避免溢出屏幕。
    function openWindowMenu(identifier, title, workspace, x, y) {
        overviewScope.menuTargetId = identifier;
        overviewScope.menuTargetTitle = title;
        overviewScope.menuTargetWorkspace = workspace;
        overviewScope.menuAction = "";
        overviewScope.menuStage = 1;
        overviewScope.menuX = Math.max(0, Math.min(x, panelWindow.width - 260));
        overviewScope.menuY = Math.max(0, Math.min(y, panelWindow.height - 240));
    }

    /// W-Tab 循环一步（dir=+1 前进 / -1 后退）。首次调用打开 overview 并
    /// 从当前活动窗口出发；keybind repeat 会以 ~25Hz 持续调用本函数。
    /// 与 Hyprland mod+TAB 一致：循环所有工作区的窗口（cycleWindows），
    /// 每次移动重置自动提交计时器，释放键后短超时即提交。
    ///
    /// 自适应超时（解决 labwc 无组合键 release 事件的困境）：
    ///   首次 step（刚打开）：长超时（repeatDelay + margin）。labwc 的
    ///     keybind repeat 首次触发要等 repeatDelay（600ms），若此时用短
    ///     超时会在 repeat 到来前误提交 → "闪一下就消失"。
    ///   后续 step（repeat 到来后）：短超时（150ms）。按住时每 40ms repeat
    ///     restart timer 永不触发；释放后 150ms 即提交 → 接近即时。
    ///   这样：按住停留（长超时被 repeat 不断 restart）、释放秒跳（150ms）。
    function cycleStep(dir) {
        const wins = overviewScope.cycleWindows;
        if (wins.length === 0) {
            bridge.dbg("step wins=0");
            return;
        }
        if (!overviewScope.open) {
            overviewScope.open = true;
            overviewScope.cycleMode = true;
            overviewScope.filterQuery = "";
            overviewScope.searchFocused = false;
            // 从当前活动窗口出发（Hyprland mod+TAB 从当前窗口开始）
            let start = 0;
            for (let i = 0; i < wins.length; ++i) {
                if (wins[i].active) { start = i; break; }
            }
            overviewScope.selectedIndex = start;
            // 首次：长超时，撑过 repeatDelay(600ms) + qs ipc 延迟(~40ms/次)
            // 到第一次 repeat 到达。1500ms 留充足余量，避免按住时误提交。
            commitTimer.interval = 1500;
        } else {
            // 后续 repeat 已到来：切换到长思考超时。labwc 无法精确检测
            // Win 释放（Super_L onRelease 在 chord 后不触发，且 Super release
            // 被 labwc 消费不转发 QML），故用空闲超时近似"两键都松开"：
            // 松开 Tab 后 repeat 停止，给 2000ms 思考时间——此期间再按 Tab
            // 会 restart timer 继续循环；2 秒无新 step 则提交（认为用户放弃
            // 继续切换）。repeat 期间每 40ms restart 故永不误触发。
            commitTimer.interval = 2000;
        }
        overviewScope.cycleMode = true;
        const n = wins.length;
        overviewScope.selectedIndex =
            ((overviewScope.selectedIndex + dir) % n + n) % n;
        bridge.dbg("step dir=" + dir + " open=" + overviewScope.open
            + " n=" + n + " sel=" + overviewScope.selectedIndex
            + " interval=" + commitTimer.interval);
        commitTimer.restart();
    }

    /// 释放后提交：激活选中窗口（daemon zwlr activate → labwc 自动切工作区
    /// 并聚焦）并关闭 overview。取消（Esc）走 closeOverview，不激活。
    function commitCycle() {
        bridge.dbg("commit-timer fired open=" + overviewScope.open
            + " cycle=" + overviewScope.cycleMode);
        if (!overviewScope.open)
            return;
        const wins = overviewScope.cycleWindows;
        if (overviewScope.cycleMode && wins.length > 0
                && overviewScope.selectedIndex >= 0
                && overviewScope.selectedIndex < wins.length) {
            const w = wins[overviewScope.selectedIndex];
            bridge.dbg("commit activating id=" + w.identifier);
            bridge.activateWindow(w.identifier);
        }
        overviewScope.closeOverview();
    }

    // 打开时定位到当前工作区第一个窗口
    function onOpened() {
        overviewScope.clampSelection();
        Qt.callLater(() => {
            overviewKeyHandler.forceActiveFocus();
            if (overviewScope.visibleWindows.length > 0)
                overviewScope.selectedIndex = 0;
        });
    }

    IpcHandler {
        target: "overview"

        function toggle() {
            overviewScope.dbgLastEvent = "toggle";
            overviewScope.open = !overviewScope.open;
            if (overviewScope.open)
                overviewScope.onOpened();
        }
        function dbg() {
            return overviewScope.dbgLastEvent;
        }
        function workspacesToggle() {
            overviewScope.open = !overviewScope.open;
            if (overviewScope.open)
                overviewScope.onOpened();
        }
        function close() {
            overviewScope.closeOverview();
        }
        function open() {
            overviewScope.open = true;
            overviewScope.onOpened();
        }
        function step() {
            overviewScope.cycleStep(1);
        }
        function prev() {
            overviewScope.cycleStep(-1);
        }
    }
    /// W-Tab 按住循环的自动提交：最后一次 step 后空闲超时即提交
    /// （labwc 无法精确检测 Win 释放，用空闲超时近似"两键都松开"）。
    /// interval 由 cycleStep 动态设置：首次 1500ms（撑过 repeatDelay），
    /// 后续 2000ms（松开 Tab 后给 2 秒思考时间，期间再按 Tab 可继续）。
    /// 见 cycleStep 注释。
    Timer {
        id: commitTimer
        interval: 1500
        onTriggered: overviewScope.commitCycle()
    }

    PanelWindow {
        id: panelWindow
        visible: overviewScope.open
        screen: Quickshell.screens[0]

        WlrLayershell.namespace: "quickshell:overview-labwc"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: overviewScope.open
            ? WlrKeyboardFocus.OnDemand
            : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // ── 背景 scrim（点击关闭）──
        Rectangle {
            id: scrim
            anchors.fill: parent
            color: ColorUtils.transparentize("#0a0a0e", 0.28)

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    overviewScope.dbgLastEvent = "scrim";
                    bridge.dbg("scrim-click");
                    if (overviewScope.filterQuery.length > 0) {
                        overviewScope.filterQuery = "";
                    } else {
                        overviewScope.closeOverview();
                    }
                }
            }
        }

        // ── 内容 ──
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 48
            spacing: 20

            // 顶栏：标题 + 搜索 + 关闭
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                Text {
                    text: "工作区概览"
                    color: OmarchyTheme.foreground
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }
                Text {
                    text: bridge.activeWorkspace.length > 0
                        ? `工作区 ${bridge.activeWorkspace}`
                        : "连接中…"
                    color: OmarchyTheme.accent
                    font.pixelSize: 14
                }
                Item { Layout.fillWidth: true }

                TextField {
                    id: searchField
                    Layout.preferredWidth: 260
                    placeholderText: "搜索窗口标题或应用…"
                    text: overviewScope.filterQuery
                    onTextChanged: {
                        overviewScope.filterQuery = text;
                        overviewScope.selectedIndex = 0;
                    }
                    onFocusChanged: overviewScope.searchFocused = activeFocus
                    Keys.onEscapePressed: {
                        if (overviewScope.filterQuery.length > 0) {
                            overviewScope.filterQuery = "";
                        } else {
                            overviewScope.closeOverview();
                        }
                        event.accepted = true;
                    }
                    Keys.onReturnPressed: {
                        overviewScope.activateSelected();
                        event.accepted = true;
                    }
                }

                Button {
                    text: "✕"
                    implicitWidth: 36
                    implicitHeight: 32
                    onClicked: overviewScope.closeOverview()
                }
            }

            // 工作区条
            Flow {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: bridge.workspaces

                    Rectangle {
                        required property var modelData
                        readonly property bool isActive: modelData.active
                        width: chipText.implicitWidth + 28
                        height: 30
                        radius: 6
                        color: isActive ? OmarchyTheme.accent
                                        : ColorUtils.transparentize("#ffffff", 0.88)
                        border.color: isActive ? OmarchyTheme.accentActiveBorder
                                               : "#3a3a45"
                        border.width: 1

                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: modelData.name
                            color: isActive ? OmarchyTheme.background
                                            : OmarchyTheme.foreground
                            font.pixelSize: 13
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                bridge.activateWorkspace(modelData.name);
                                overviewScope.closeOverview();
                            }
                        }
                    }
                }
            }

            // daemon 状态提示
            Rectangle {
                Layout.fillWidth: true
                visible: !bridge.connected
                height: visible ? 32 : 0
                radius: 6
                color: "#3a2a10"

                Text {
                    anchors.centerIn: parent
                    text: "thumbnaild 未运行：无法获取窗口缩略图（仍可切换工作区）"
                    color: "#ffcf8a"
                    font.pixelSize: 12
                }
            }

            // 窗口网格
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Flickable {
                    id: gridFlickable
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: gridColumn.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: gridColumn
                        width: gridFlickable.width
                        spacing: 16

                        Flow {
                            id: gridFlow
                            width: gridColumn.width
                            spacing: 16

                            Repeater {
                                model: overviewScope.displayWindows

                                Rectangle {
                                    required property var modelData
                                    required property int index
                                    readonly property int itemIndex: index
                                    readonly property bool isSelected: itemIndex === overviewScope.selectedIndex
                                    readonly property bool isActive: modelData.active
                                    readonly property bool unknownWs: modelData.workspace === ""

                                    width: (gridFlow.width - 16 * (overviewScope.gridColumns - 1)) / overviewScope.gridColumns
                                    height: Math.min(260, width * 0.62 + 40)
                                    radius: 10
                                    color: "#16161d"
                                    border.color: isSelected ? OmarchyTheme.accentActiveBorder
                                        : (isActive ? OmarchyTheme.accentBorder : "#33333d")
                                    border.width: isSelected ? 2 : 1

                                    Rectangle {
                                        id: thumbBox
                                        anchors {
                                            top: parent.top
                                            left: parent.left
                                            right: parent.right
                                            margins: 8
                                        }
                                        height: parent.height - 48
                                        radius: 6
                                        clip: true
                                        color: "#0d0d12"

                                        Image {
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            source: (modelData.exists && modelData.thumb.length > 0)
                                                ? `file://${modelData.thumb}?v=${bridge.seq}`
                                                : ""
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: !modelData.exists
                                            text: modelData.app_id.length > 0 ? modelData.app_id : modelData.title
                                            color: "#5a5a66"
                                            font.pixelSize: 12
                                            elide: Text.ElideMiddle
                                            width: parent.width - 24
                                        }
                                    }

                                    Text {
                                        anchors {
                                            left: parent.left
                                            right: parent.right
                                            bottom: parent.bottom
                                            margins: 10
                                        }
                                        text: modelData.title.length > 0 ? modelData.title
                                                                         : (modelData.app_id || "未知窗口")
                                        color: OmarchyTheme.foreground
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    // 工作区角标：循环模式显示窗口所属工作区
                                    // （未知归属 "?"）；普通模式仅未知窗口显示 "?"
                                    Rectangle {
                                        visible: unknownWs || overviewScope.cycleMode
                                        width: 18
                                        height: 18
                                        radius: 9
                                        color: "#3a3a45"
                                        anchors {
                                            top: parent.top
                                            right: parent.right
                                            margins: 6
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.workspace.length > 0
                                                ? modelData.workspace : "?"
                                            color: OmarchyTheme.foreground
                                            font.pixelSize: 11
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: (mouse) => {
                                            if (mouse.button === Qt.RightButton) {
                                                const pos = mapToItem(windowMenuLayer,
                                                    mouse.x, mouse.y);
                                                overviewScope.openWindowMenu(
                                                    modelData.identifier,
                                                    modelData.title.length > 0
                                                        ? modelData.title : modelData.app_id,
                                                    modelData.workspace, pos.x, pos.y);
                                                return;
                                            }
                                            overviewScope.dbgLastEvent = "thumb idx=" + itemIndex
                                                + " id=[" + modelData.identifier + "]"
                                                + " connected=" + bridge.connected;
                                            bridge.dbg("thumb-click idx=" + itemIndex
                                                + " id=" + modelData.identifier
                                                + " connected=" + bridge.connected);
                                            overviewScope.selectedIndex = itemIndex;
                                            bridge.activateWindow(modelData.identifier);
                                            overviewScope.closeOverview();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 空状态
                Column {
                    anchors.centerIn: parent
                    visible: overviewScope.displayWindows.length === 0
                    spacing: 8

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: bridge.connected
                            ? (overviewScope.cycleMode
                                ? "没有可切换的窗口"
                                : "当前工作区没有窗口")
                            : "正在连接 thumbnaild…"
                        color: "#8a8a96"
                        font.pixelSize: 15
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: overviewScope.filterQuery.length > 0
                        text: "没有匹配「" + overviewScope.filterQuery + "」的窗口"
                        color: "#6a6a76"
                        font.pixelSize: 12
                    }
                }
            }
        }

        // ── 右键窗口菜单：发送到工作区（两项）──
        Item {
            id: windowMenuLayer
            anchors.fill: parent
            visible: overviewScope.menuStage > 0
            z: 1500

            // 点击菜单外关闭
            MouseArea {
                anchors.fill: parent
                onClicked: overviewScope.menuStage = 0
            }

            // 菜单卡片（主题化：TuiStyle tokens，与其它 ContextMenu 一致）
            Rectangle {
                x: overviewScope.menuX
                y: overviewScope.menuY
                width: 252
                height: menuColumn.implicitHeight + 8
                radius: TuiStyle.shellRadius
                color: TuiStyle.bg
                border.width: TuiStyle.borderWidth
                border.color: TuiStyle.menuBorder

                ColumnLayout {
                    id: menuColumn
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 0

                    // 目标窗口标题
                    Text {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        leftPadding: 10
                        rightPadding: 10
                        verticalAlignment: Text.AlignVCenter
                        text: overviewScope.menuTargetTitle
                        color: ColorUtils.transparentize(OmarchyTheme.foreground, 0.35)
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                    ContextMenuSeparator {
                        Layout.fillWidth: true
                    }

                    // stage 1：动作选择
                    ContextMenuItem {
                        visible: overviewScope.menuStage === 1
                        nerdIcon: NerdIconMap.arrowForward
                        labelText: "静默发送到工作区…"
                        onClicked: {
                            overviewScope.menuAction = "silent";
                            overviewScope.menuStage = 2;
                        }
                    }
                    ContextMenuItem {
                        visible: overviewScope.menuStage === 1
                        nerdIcon: NerdIconMap.chevronRight
                        labelText: "发送并前往工作区…"
                        onClicked: {
                            overviewScope.menuAction = "follow";
                            overviewScope.menuStage = 2;
                        }
                    }

                    // stage 2：选择目标工作区（窗口当前所在工作区禁用）
                    Repeater {
                        model: bridge.workspaces
                        visible: overviewScope.menuStage === 2
                        delegate: ContextMenuItem {
                            required property var modelData
                            readonly property bool isCurrent: modelData.name
                                === overviewScope.menuTargetWorkspace
                            labelText: "工作区 " + modelData.name
                                + (isCurrent ? "（当前）" : "")
                            enabled: !isCurrent
                            onClicked: {
                                bridge.sendToWorkspace(
                                    overviewScope.menuTargetId, modelData.name,
                                    overviewScope.menuAction === "follow");
                                overviewScope.menuStage = 0;
                                if (overviewScope.menuAction === "follow")
                                    overviewScope.closeOverview();
                            }
                        }
                    }
                }
            }
        }

        // ── 键盘控制 ──
        Item {
            id: overviewKeyHandler
            anchors.fill: parent
            z: 999
            focus: overviewScope.open && !overviewScope.searchFocused

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    if (overviewScope.filterQuery.length > 0) {
                        overviewScope.filterQuery = "";
                    } else {
                        overviewScope.closeOverview();
                    }
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                    overviewScope.moveSelection(-1, 0);
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                    overviewScope.moveSelection(1, 0);
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    overviewScope.moveSelection(0, -1);
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    overviewScope.moveSelection(0, 1);
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                    || event.key === Qt.Key_Space) {
                    overviewScope.activateSelected();
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Tab && overviewScope.cycleMode) {
                    // 循环模式下 Tab 前进 / Shift+Tab 后退（keybind repeat
                    // 的兜底：松开后想继续走可重按）
                    overviewScope.cycleStep(
                        (event.modifiers & Qt.ShiftModifier) ? -1 : 1);
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
                    searchField.forceActiveFocus();
                    event.accepted = true;
                    return;
                }
            }

            Connections {
                target: overviewScope
                function onOpenChanged() {
                    if (!overviewScope.open) {
                        overviewKeyHandler.focus = false;
                    } else {
                        overviewKeyHandler.forceActiveFocus();
                    }
                }
            }
        }
    }
}
