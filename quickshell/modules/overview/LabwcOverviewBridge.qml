pragma Singleton
import qs
import QtQuick
import Quickshell
import Quickshell.Io

/// labwc 分支的 overview 数据桥。
///
/// 连接 thumbnaild 的 unix socket（labwc 会话专用），接收 JSON 行快照
/// （窗口枚举 + 缩略图路径 + 工作区状态），并转发激活命令。
/// 仅在 labwc 会话由 LabwcOverview 实例化；Hyprland 会话不加载本文件。
Singleton {
    id: root

    /// 当前是否与 thumbnaild 保持连接（daemon 未运行时为 false）
    property bool connected: false
    /// 快照序号（每次广播递增，用作缩略图 URL 的 cache-buster）
    property int seq: 0
    property string activeWorkspace: ""
    /// [{ name, active }]
    property var workspaces: []
    /// [{ identifier, title, app_id, workspace, active, exists, thumb }]
    property var windows: []
    /// 最近一次 socket 错误描述（用于 UI 提示）
    property string lastError: ""

    readonly property string socketPath: {
        const runtime = Quickshell.env("SUMIKA_SHELL_RUNTIME_DIR")
            || `${Quickshell.env("XDG_RUNTIME_DIR") || ""}/sumika-shell`;
        return runtime + "/overview-thumbnaild.sock";
    }

    /// 断线自动重连（daemon 由 labwc 会话拉起，可能晚于 overview 进程）。
    /// Socket.connected 是"期望连接状态"：连接失败后重复赋 true 不会触发
    /// 重连（状态未变），必须先断开再重新请求（Quickshell Socket 文档的
    /// reconnect 模式）。实测：daemon 缺失期间启动的 overview 仅靠
    /// `socket.connected = true` 无法在 daemon 就绪后连上（2026-08-09）。
    Timer {
        id: reconnectTimer
        interval: 2000
        running: !root.connected
        onTriggered: {
            socket.connected = false;
            socket.connected = true;
        }
    }

    Socket {
        id: socket
        path: root.socketPath
        connected: true
        parser: SplitParser {
            onRead: (line) => {
                if (!line.trim())
                    return;
                root.handleSnapshot(line);
            }
        }
        onConnectionStateChanged: {
            root.connected = socket.connected;
            if (!socket.connected)
                reconnectTimer.restart();
        }
        onError: (error) => {
            root.lastError = error;
        }
    }

    function handleSnapshot(line) {
        let msg;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            return; // 忽略畸形行（部分 TCP 读包等）
        }
        if (!msg || msg.type !== "snapshot")
            return;
        root.seq = msg.seq ?? root.seq;
        root.activeWorkspace = msg.activeWorkspace ?? "";
        root.workspaces = msg.workspaces ?? [];
        const wins = msg.windows ?? [];
        root.windows = wins.map(w => ({
            identifier: w.identifier ?? "",
            title: w.title ?? "",
            app_id: w.app_id ?? "",
            workspace: w.workspace ?? "",
            active: !!w.active,
            exists: !!w.exists,
            thumb: w.thumb ?? "",
        }));
    }

    function sendCommand(obj) {
        if (!root.connected)
            return;
        socket.write(JSON.stringify(obj) + "\n");
    }

    /// 切换到指定工作区（ext-workspace activate）
    function activateWorkspace(name) {
        sendCommand({ cmd: "activate-workspace", name: name });
    }

    /// 聚焦指定窗口（zwlr activate：切桌面 + 聚焦一步完成）
    function activateWindow(identifier) {
        console.log("[OVERVIEW-DBG] bridge.activateWindow id=[" + identifier
            + "] connected=" + root.connected);
        sendCommand({ cmd: "activate-window", identifier: identifier });
    }

    /// 发送窗口到指定工作区（daemon 先聚焦该窗口，再用 ydotool 合成
    /// rc.xml 的 W-S-N / W-S-A-N keybind 触发 labwc SendToDesktop）
    function sendToWorkspace(identifier, workspace, follow) {
        sendCommand({ cmd: "send-to-workspace", identifier: identifier,
                      workspace: workspace, follow: follow });
    }

    /// 强制刷新缩略图
    function refresh() {
        sendCommand({ cmd: "refresh" });
    }

    /// 调试标记：daemon 会把每条 socket 命令写入 stderr
    /// （wayland-session.log），用于区分"点击未触发 / 未到 daemon"。
    function dbg(msg) {
        sendCommand({ cmd: "dbg", msg: msg });
    }
}
