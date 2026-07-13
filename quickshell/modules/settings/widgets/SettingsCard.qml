import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: card
    property string title: ""
    property string subtitle: ""
    default property alias content: contentColumn.children

    Layout.fillWidth: true
    implicitHeight: cardColumn.implicitHeight + 32
    radius: 0
    color: SettingsTokens.card
    border.width: 1
    border.color: Qt.rgba(SettingsTokens.line.r, SettingsTokens.line.g, SettingsTokens.line.b, TuiStyle.dividerOpacity)

    ColumnLayout {
        id: cardColumn
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        ColumnLayout {
            id: contentColumn
            Layout.fillWidth: true
            spacing: 4
        }
    }
}