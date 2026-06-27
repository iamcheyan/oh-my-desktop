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

    CircleUtilButton {
        id: audioButton
        anchors.centerIn: parent

        onClicked: {
            GlobalStates.barAudioIsSink = true;
            GlobalStates.barDialogType = "audio";
            GlobalStates.barDialogOpen = true;
        }

        onHoveredChanged: {
            if (audioButton.hovered)
                audioPopupLoader.open();
            else
                audioPopupLoader.close();
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
        active: false

        function open() {
            audioPopupTimer.stop();
            audioPopupLoader.active = true;
        }

        function close() {
            audioPopupTimer.restart();
        }

        Timer {
            id: audioPopupTimer
            interval: 300
            repeat: false
            onTriggered: audioPopupLoader.active = false
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
                audioPopupLoader.active = false;
            }
        }
    }
}