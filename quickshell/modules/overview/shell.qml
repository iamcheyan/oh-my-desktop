//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_IM_MODULE=fcitx

import qs.modules.common

import qs.modules.overview
import qs.services

import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: root

    PanelWindow {
        id: keepAliveWindow
        visible: true
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:overview-keepalive"
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors {
            top: true
            left: true
        }

        // Keep one real scene-graph image alive so the wallpaper is decoded
        // before the on-demand overview widget is created. A hidden Image in
        // a singleton is not guaranteed to load because it has no window.
        Image {
            anchors.fill: parent
            visible: true
            opacity: 0
            source: Wallpaper.requestedUrl
            asynchronous: Wallpaper.readyUrl != ""
            cache: true

            onSourceChanged: {
                if (source == "")
                    Wallpaper.readyUrl = "";
            }
            onStatusChanged: {
                if (status === Image.Ready)
                    Wallpaper.readyUrl = source;
            }
        }
    }

    // 条件加载 overview 根组件：
    //   - labwc 会话（XDG_CURRENT_DESKTOP=labwc）→ LabwcOverview，自
    //     thumbnaild 取窗口缩略图（Hyprland 版 Overview 深度绑定
    //     Quickshell.Hyprland，labwc 下无数据源，不可实例化）。
    //   - 其余（Hyprland 等）→ 现有 Overview。
    // SystemInfo.desktopEnvironment 由 bash 异步填充，就绪前挂空组件；
    // keepAliveWindow 已存在，进程不会因空 loader 退出。
    //
    // Keep the overview process alive even while Config is still loading.
    // If this is wrapped in a loader gated by Config.ready, Quickshell can exit
    // during login/reload before any PanelWindow is created.
    Loader {
        id: overviewLoader
        active: true
        sourceComponent: {
            const de = (SystemInfo.desktopEnvironment || "").toLowerCase();
            if (de === "labwc")
                return labwcOverviewComponent;
            if (de.length === 0)
                return null; // SystemInfo 未就绪
            return hyprOverviewComponent;
        }
    }

    Component {
        id: labwcOverviewComponent
        LabwcOverview {}
    }
    Component {
        id: hyprOverviewComponent
        Overview {}
    }
}
