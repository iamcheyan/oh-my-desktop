import Quickshell
import qs.modules.bar
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

CircleUtilButton {
    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.fillHeight: true
    onClicked: Idle.toggleInhibit()
    Item {
        implicitWidth: 20
        implicitHeight: 20
        property bool hovered: parent.hovered
        CosmicIcon {
            anchors.centerIn: parent
            name: Idle.inhibit ? "actions/document-properties-symbolic" : "actions/image-red-eye-symbolic"
            iconSize: Appearance.font.pixelSize.larger + 1
            color: Appearance.colors.colBarText
        }
        PopupToolTip {
            text: Idle.inhibit ? Translation.tr("Auto-sleep disabled") : Translation.tr("Auto-sleep enabled")
            anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
        }
    }
}
