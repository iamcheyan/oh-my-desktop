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
    onClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_SOURCE@", "toggle"])
    Item {
        implicitWidth: 20
        implicitHeight: 20
        property bool hovered: parent.hovered
        CosmicIcon {
            anchors.centerIn: parent
            name: Pipewire.defaultAudioSource?.audio?.muted ? "status/microphone-sensitivity-muted-symbolic" : "status/microphone-sensitivity-high-symbolic"
            iconSize: Appearance.font.pixelSize.larger + 1
            color: Appearance.colors.colBarText
        }
        PopupToolTip {
            text: Translation.tr("Microphone")
            anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
        }
    }
}
