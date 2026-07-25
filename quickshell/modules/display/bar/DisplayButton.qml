import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

BarModuleButton {
    icon: NerdIconMap.desktop
    moduleId: "display"
    active: GlobalStates.barPopupType === "display"
    onClicked: {
        if (Date.now() - GlobalStates.barPopupDismissedAt < 200) return;
        GlobalStates.barPopupType = GlobalStates.barPopupType === "display" ? "" : "display";
    }
}
