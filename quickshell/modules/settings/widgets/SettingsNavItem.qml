import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: nav
    property string iconName: ""
    property string label: ""
    property bool selected: false
    signal clicked()

    Layout.preferredHeight: 38
    radius: SettingsTokens.roundRadius
    color: selected ? SettingsTokens.accentSoft : navMouse.containsMouse ? SettingsTokens.panelAlt : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        spacing: 12

        MaterialSymbol {
            text: nav.iconName
            iconSize: 18
            color: nav.selected ? SettingsTokens.accent : SettingsTokens.muted
        }

        StyledText {
            Layout.fillWidth: true
            text: nav.label
            color: nav.selected ? SettingsTokens.accent : SettingsTokens.muted
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: nav.selected ? Font.Medium : Font.Normal
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: navMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: nav.clicked()
    }
}