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

    readonly property bool needsSetup: KeyboardRemap.state === "setup" || !KeyboardRemap.keydReady

    BarNerdIcon {
        id: icon
        anchors.centerIn: parent
        text: NerdIconMap.keyboard
        color: root.needsSetup ? "#F5C542" : Appearance.colors.colBarText
    }

    MouseArea {
        id: interactionArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.ArrowCursor
        onPressed: event => {
            if (event.button === Qt.RightButton)
                KeyboardRemap.openSettings();
        }
    }

    KeyboardRemapHoverPopup {
        hoverTarget: interactionArea
    }
}