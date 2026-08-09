import qs
import qs.services
import qs.core.runtime
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property string moduleId: "workspaces"

    /// labwc 会话：workspaces 按钮降级为"当前工作区编号"，点击打开 labwc
    /// 原生工作区一览菜单（client-list-combined-menu，经 W-A-w keybind）。
    /// Hyprland 会话维持原 overview 行为。
    property bool labwcMode: false
    /// daemon socket 是否已连接（daemon 未运行 / 启动晚于 bar 时为 false）
    property bool connected: false
    /// 当前工作区名（来自 labwc-workspace daemon；连接前显示 "--"）
    property string activeWorkspace: "--"

    readonly property string daemonSocketPath: {
        const runtime = Quickshell.env("SUMIKA_SHELL_RUNTIME_DIR")
            || `${Quickshell.env("XDG_RUNTIME_DIR") || ""}/sumika-shell`;
        return runtime + "/labwc-workspace.sock";
    }

    function toggleWorkspaces() {
        if (root.labwcMode) {
            // bar 是 layer surface，labwc 的鼠标绑定管不到它；注入按键
            // 触发 rc.xml 的 W-A-w → ShowMenu client-list-combined-menu。
            Quickshell.execDetached(["wtype", "-M", "logo", "-M", "alt", "w",
                                     "-m", "logo", "-m", "alt"]);
        } else {
            ActionManager.invoke("overview.open");
        }
    }

    implicitWidth: workspacesButton.implicitWidth
    implicitHeight: workspacesButton.implicitHeight

    BarTextButton {
        id: workspacesButton
        text: root.labwcMode ? `workspaces[${root.activeWorkspace}]` : "Workspaces"
        onTriggered: root.toggleWorkspaces()
    }

    // ---- 桌面检测（与 SystemInfo.qml 同款 Process 探环境变量）----
    Process {
        id: desktopProbe
        running: true
        command: ["bash", "-c", "echo $XDG_CURRENT_DESKTOP"]
        stdout: SplitParser {
            onRead: line => {
                root.labwcMode = line.trim() === "labwc"
            }
        }
    }

    onLabwcModeChanged: {
        // 手动控制期望连接状态（不绑定）：重连需要先断开再连接
        // （Quickshell Socket 行为，2026-08-09 实测）。
        socket.connected = root.labwcMode;
    }

    // ---- labwc-workspace daemon socket（仅 labwc 下连接）----
    // daemon 由 labwc 会话 autostart 拉起，可能晚于 bar；断线自动重连。
    Timer {
        id: reconnectTimer
        interval: 2000
        running: root.labwcMode && !root.connected
        onTriggered: {
            socket.connected = false;
            socket.connected = true;
        }
    }

    Socket {
        id: socket
        path: root.daemonSocketPath
        connected: false
        parser: SplitParser {
            onRead: line => {
                const name = line.trim();
                if (name.length > 0)
                    root.activeWorkspace = name;
            }
        }
        onConnectionStateChanged: {
            root.connected = socket.connected;
            if (!socket.connected)
                reconnectTimer.restart();
        }
    }

    Component {
        id: hoverComponent
        HoverInfo {}
    }

    Component.onCompleted: HoverInfoService.register(root.moduleId, hoverComponent)
    Component.onDestruction: HoverInfoService.unregister(root.moduleId)

    HoverInfoPopup {
        moduleId: root.moduleId
        hoverTarget: workspacesButton
    }
}
