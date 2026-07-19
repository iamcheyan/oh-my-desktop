//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_IM_MODULE=fcitx

import "modules/common"
import "services"

import qs.modules.overview

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

    // Keep the overview process alive even while Config is still loading.
    // If this is wrapped in a loader gated by Config.ready, Quickshell can exit
    // during login/reload before any PanelWindow is created.
    Overview {}
}
