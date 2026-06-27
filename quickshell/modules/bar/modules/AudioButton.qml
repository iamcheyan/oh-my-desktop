import Quickshell
import qs.modules.bar
import qs
import qs.services
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

    MouseArea {
        id: wheelArea
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true
        onWheel: wheel => {
            const r = WheelUtils.getSteps(wheel.angleDelta.y, root.wheelAccum)
            root.wheelAccum = r.accum
            for (let i = 0; i < Math.abs(r.steps); i++) {
                if (r.steps > 0)
                    Audio.incrementVolume();
                else if (r.steps < 0)
                    Audio.decrementVolume();
            }
            wheel.accepted = true;
            GlobalStates.openBarPopup("audio");
        }
    }

    CircleUtilButton {
        id: audioButton
        anchors.centerIn: parent

        onClicked: {
            GlobalStates.toggleBarPopup("audio");
        }

        content: Item {
            id: audioIconHost
            implicitWidth: 20
            implicitHeight: 20

            CosmicIcon {
                anchors.centerIn: parent
                name: Audio.sink?.audio?.muted ? "status/audio-volume-muted-symbolic" : "status/audio-volume-high-symbolic"
                iconSize: Config.options.bar.rightIconSize
                color: Appearance.colors.colBarText
            }
        }
    }

    Loader {
        id: audioPopupLoader
        active: GlobalStates.barPopupType === "audio"

        function open() {
            GlobalStates.openBarPopup("audio");
        }

        function close() {
            GlobalStates.closeBarPopup("audio");
        }

        sourceComponent: AudioInfoPopup {
            Component.onCompleted: this.visible = true
            anchor {
                window: root.QsWindow.window
                item: root.parent?.parent ?? root
                gravity: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
                edges: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
            }
            onMenuClosed: {
                GlobalStates.closeBarPopup("audio");
            }
            onManageRequested: {
                GlobalStates.barAudioIsSink = true;
                GlobalStates.barDialogType = "audio";
                GlobalStates.barDialogOpen = true;
            }
        }
    }
}
