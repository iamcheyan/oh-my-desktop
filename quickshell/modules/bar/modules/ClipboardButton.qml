import Quickshell
import qs.modules.bar
import qs
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

    readonly property real barHeight: Config.options.bar.cornerStyle === 1
        ? (32 + Appearance.sizes.hyprlandGapsOut * 2) : 32

    CircleUtilButton {
        id: clipboardButton
        anchors.centerIn: parent

        onClicked: {
            Quickshell.execDetached([
                `${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-clipboard`,
                "toggle-at-bar",
                `${root.barHeight}`
            ]);
        }

        content: BarNerdIcon {
            text: NerdIconMap.contentPaste
            color: Appearance.colors.colBarText
        }
    }
}
