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
    radius: SettingsTokens.roundRadius
    color: SettingsTokens.card
    border.width: 1
    border.color: Qt.rgba(SettingsTokens.line.r, SettingsTokens.line.g, SettingsTokens.line.b, TuiStyle.dividerOpacity)

    ColumnLayout {
        id: cardColumn
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            visible: card.title.length > 0 || card.subtitle.length > 0
            spacing: 10

            StyledText {
                Layout.fillWidth: true
                text: card.title
                color: SettingsTokens.fg
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            StyledText {
                visible: card.subtitle.length > 0
                text: card.subtitle
                color: SettingsTokens.muted
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
            }
        }

        ColumnLayout {
            id: contentColumn
            Layout.fillWidth: true
            spacing: 4
        }
    }
}