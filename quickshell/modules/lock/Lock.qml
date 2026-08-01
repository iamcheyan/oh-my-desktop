pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.panels.lock
import QtQuick
import Quickshell

LockScreen {
    id: root

    lockSurface: LockSurface {
        context: root.context
    }

    Component.onCompleted: LockService.register(() => root.lock())
    Component.onDestruction: LockService.register(null)
}