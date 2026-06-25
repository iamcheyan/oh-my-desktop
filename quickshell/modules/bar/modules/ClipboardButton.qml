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
    onClicked: {
        Quickshell.execDetached(["bash", "-c", "~/.config/omd/bin/omd-clipboard-pick"]);
    }
    Item {
        implicitWidth: 20
        implicitHeight: 20
        property bool hovered: parent.hovered
        CosmicIcon {
            anchors.centerIn: parent
            name: "actions/edit-paste-symbolic"
            iconSize: Config.options.bar.rightIconSize
            color: Appearance.colors.colBarText
        }
        PopupToolTip {
            text: Translation.tr("Clipboard")
            anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
        }
    }
}
