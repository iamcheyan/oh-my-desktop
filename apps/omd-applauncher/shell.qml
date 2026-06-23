//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_IM_MODULE=fcitx

import "modules/common"
import "services"

import qs.modules.ii.appLauncher

import QtQuick
import Quickshell

ShellRoot {
    id: root

    ReloadPopup {}

    LazyLoader {
        active: Config.ready
        component: AppLauncher {}
    }
}