import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell

BarModuleButton {
    icon: NerdIconMap.contentPaste
    moduleId: "clipboard"
    active: false
    onClicked: {
        if (Date.now() - GlobalStates.barPopupDismissedAt < 200) return;
        Quickshell.execDetached([
            "sumika-clipboard",
            "toggle-at-bar",
            // Pass actual bar height so clipboard positions at the same Y as BarStatusPopup.
            String(Appearance.sizes.barHeight)
        ]);
    }
}
