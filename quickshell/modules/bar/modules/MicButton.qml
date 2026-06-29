import qs.modules.bar
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

CircleUtilButton {
    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.fillHeight: true
    onClicked: {
        GlobalStates.barAudioIsSink = false;
        GlobalStates.barDialogType = "audio";
        GlobalStates.barDialogOpen = true;
    }
    Item {
        implicitWidth: 20
        implicitHeight: 20
        property bool hovered: parent.hovered
        BarNerdIcon {
            anchors.centerIn: parent
            text: Pipewire.defaultAudioSource?.audio?.muted ? NerdIconMap.micOff : NerdIconMap.mic
            color: Appearance.colors.colBarText
        }
    }
}
