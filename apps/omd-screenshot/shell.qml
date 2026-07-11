//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_IM_MODULE=fcitx

import qs
import "modules/regionSelector"
import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root

    Component.onCompleted: {
        Config.blockWrites = true;
    }

    Connections {
        target: GlobalStates
        function onRegionSelectorOpenChanged() {
            if (!GlobalStates.regionSelectorOpen) {
                Qt.quit();
            }
        }
    }

    RegionSelector {}
}
