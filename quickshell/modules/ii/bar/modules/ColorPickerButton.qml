import qs.modules.ii.bar
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

CircleUtilButton {
    Layout.alignment: Qt.AlignVCenter
    onClicked: Quickshell.execDetached(["hyprpicker", "-a"])
    Item {
        implicitWidth: 20
        implicitHeight: 20
        property bool hovered: parent.hovered
        CosmicIcon {
            anchors.centerIn: parent
            name: "actions/pencil-symbolic"
            iconSize: Appearance.font.pixelSize.larger + 1
            color: Appearance.colors.colBarText
        }
        PopupToolTip {
            text: Translation.tr("Color picker")
            anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
        }
    }
}
