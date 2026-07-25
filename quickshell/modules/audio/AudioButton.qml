import Quickshell
import qs
import qs.core.runtime
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.fillHeight: true
    implicitWidth: Config.options.bar.rightIconSlotWidth
    implicitHeight: Config.options.bar.rightIconSlotWidth
    property real wheelAccum: 0
    property string moduleId: "audio"

    readonly property string volumeIcon: {
        if (ServiceManager.audio?.sink?.audio?.muted) return NerdIconMap.volumeOff
        const vol = ServiceManager.audio?.sink?.audio?.volume ?? 0
        if (vol > 0.66) return NerdIconMap.volumeHigh
        if (vol > 0.33) return NerdIconMap.volumeMedium
        return NerdIconMap.volumeLow
    }

    RippleButton {
        id: actionButton
        anchors.centerIn: parent
        width: Config.options.bar.rightIconSlotWidth
        height: Config.options.bar.rightIconSlotWidth
        buttonRadius: Config.options.bar.rightIconSlotWidth / 2

        colBackground: "transparent"
        colBackgroundHover: Qt.rgba(1, 1, 1, 0.10)
        colBackgroundToggled: Qt.rgba(1, 1, 1, 0.18)
        colBackgroundToggledHover: Qt.rgba(1, 1, 1, 0.26)
        colRipple: Qt.rgba(1, 1, 1, 0.12)
        colRippleToggled: Qt.rgba(1, 1, 1, 0.18)
        toggled: GlobalStates.barPopupType === "audio"

        onClicked: {
            if (Date.now() - GlobalStates.barPopupDismissedAt < 200) return;
            const opening = GlobalStates.barPopupType !== "audio"
            GlobalStates.barPopupEphemeral = false
            GlobalStates.barPopupType = opening ? "audio" : ""
        }
    }

    BarNerdIcon {
        id: icon
        anchors.centerIn: actionButton
        text: root.volumeIcon
        color: Appearance.colors.colBarText
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
                    ServiceManager.audio?.incrementVolume?.()
                else if (r.steps < 0)
                    ServiceManager.audio?.decrementVolume?.()
            }
            wheel.accepted = true
        }
    }

    // ── Right-click: hide menu ─────────────────────────────────
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        z: 10
        onPressed: event => {
            if (event.button === Qt.RightButton)
                hideMenuLoader.open();
        }
    }

    Loader {
        id: hideMenuLoader
        function open() {
            if (hideMenuLoader.item)
                hideMenuLoader.item.open();
            else
                hideMenuLoader.active = true;
        }
        active: false
        sourceComponent: ModuleHideMenu {
            moduleId: root.moduleId
            anchor {
                window: actionButton.QsWindow.window
                item: actionButton
                gravity: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
                edges: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
            }
            Component.onCompleted: hideMenuLoader.open()
            onMenuClosed: hideMenuLoader.active = false
        }
    }
}
