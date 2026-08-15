pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.core.runtime
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root
    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.fillHeight: true
    implicitWidth: Appearance.sizes.rightIconSlotSize
    implicitHeight: Appearance.sizes.rightIconSlotSize
    property real wheelAccum: 0
    property string moduleId: "display"
    property string wallpaperMode: ""

    // Watch wallpaper mode from runtime state (long-lived, pre-read before context menu opens)
    FileView {
        path: `${Directories.sumikaStateHome}/wallpaper/mode`
        watchChanges: true
        onLoaded: root.wallpaperMode = text().trim()
        onLoadFailed: root.wallpaperMode = ""
    }

    RippleButton {
        id: actionButton
        anchors.centerIn: parent
        width: Appearance.sizes.rightIconSlotSize
        height: Appearance.sizes.rightIconSlotSize
        buttonRadius: Appearance.sizes.rightIconSlotSize / 2

        colBackground: "transparent"
        colBackgroundHover: Qt.rgba(1, 1, 1, 0.10)
        colBackgroundToggled: Qt.rgba(1, 1, 1, 0.18)
        colBackgroundToggledHover: Qt.rgba(1, 1, 1, 0.26)
        colRipple: Qt.rgba(1, 1, 1, 0.12)
        colRippleToggled: Qt.rgba(1, 1, 1, 0.18)
        toggled: GlobalStates.barPopupType === "display"

        onClicked: {
            if (Date.now() - GlobalStates.barPopupDismissedAt < 200) return;
            GlobalStates.barPopupType = GlobalStates.barPopupType === "display" ? "" : "display";
        }

        altAction: function(event) {
            displayContextMenu.open();
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
        hoverTarget: actionButton
    }

    BarNerdIcon {
        anchors.centerIn: actionButton
        text: NerdIconMap.desktop
        color: Appearance.colors.colBarText
    }

    BarContextMenu {
        id: displayContextMenu
        anchorItem: actionButton
        sourceComponent: DisplayContextMenu {
                wallpaperMode: root.wallpaperMode
            }
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
