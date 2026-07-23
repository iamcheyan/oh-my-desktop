import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

BarModuleButton {
    icon: NerdIconMap.workspaceSnapshot
    active: GlobalStates.barPopupType === "session"
    onClicked: {
        if (Date.now() - GlobalStates.barPopupDismissedAt < 200) return;
        GlobalStates.barPopupType = GlobalStates.barPopupType === "session" ? "" : "session";
    }
}
