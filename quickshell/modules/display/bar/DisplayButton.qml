import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick

BarModuleButton {
    id: root
    icon: NerdIconMap.desktop
    moduleId: "display"
    active: GlobalStates.barPopupType === "display"
    property real wheelAccum: 0
    onClicked: {
        if (Date.now() - GlobalStates.barPopupDismissedAt < 200) return;
        GlobalStates.barPopupType = GlobalStates.barPopupType === "display" ? "" : "display";
    }

    MouseArea {
        z: 20
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            const r = WheelUtils.getSteps(wheel.angleDelta.y, root.wheelAccum)
            root.wheelAccum = r.accum
            for (let i = 0; i < Math.abs(r.steps); i++) {
                if (r.steps > 0)
                    Brightness.increaseBrightness()
                else if (r.steps < 0)
                    Brightness.decreaseBrightness()
            }
            wheel.accepted = true
        }
    }
}

