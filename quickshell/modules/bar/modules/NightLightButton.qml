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
        GlobalStates.barDialogType = "nightlight";
        GlobalStates.barDialogOpen = true;
    }
    Item {
        implicitWidth: 20
        implicitHeight: 20
        property bool hovered: parent.hovered
        CosmicIcon {
            anchors.centerIn: parent
            name: Hyprsunset.temperatureActive ? "status/weather-clear-night-symbolic" : "status/display-brightness-off-symbolic"
            iconSize: Config.options.bar.rightIconSize
            color: Appearance.colors.colBarText
        }

    }
}
