import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property string iconName: ""
    property string title: ""
    property string subtitle: ""
    property string stateText: ""
    property bool warning: false
    property string actionLabel: ""
    property string actionIcon: ""
    signal actionClicked()

    Layout.fillWidth: true
    implicitHeight: summaryColumn.implicitHeight + 24
    radius: SettingsTokens.roundRadius
    color: root.warning ? SettingsTokens.warningPanel : SettingsTokens.card
    border.width: 1
    border.color: root.warning ? SettingsTokens.warningBorder : Qt.rgba(SettingsTokens.line.r, SettingsTokens.line.g, SettingsTokens.line.b, TuiStyle.dividerOpacity)

    RowLayout {
        id: summaryColumn
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        MaterialSymbol {
            visible: root.iconName.length > 0
            Layout.preferredWidth: visible ? 28 : 0
            Layout.fillHeight: true
            text: root.iconName
            iconSize: 24
            color: root.warning ? SettingsTokens.accent : SettingsTokens.muted
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: root.title
                color: SettingsTokens.fg
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            StyledText {
                visible: root.subtitle.length > 0
                Layout.fillWidth: true
                text: root.subtitle
                color: SettingsTokens.muted
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
            }

            StyledText {
                visible: root.stateText.length > 0
                Layout.fillWidth: true
                text: root.stateText
                color: root.warning ? SettingsTokens.accent : SettingsTokens.dim
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }

        Rectangle {
            visible: root.actionLabel.length > 0
            Layout.preferredWidth: actionRow.implicitWidth + 20
            Layout.preferredHeight: 36
            radius: SettingsTokens.radius
            color: actionMouse.containsMouse ? SettingsTokens.buttonHover : SettingsTokens.button
            border.width: 1
            border.color: SettingsTokens.buttonBorder

            RowLayout {
                id: actionRow
                anchors.centerIn: parent
                spacing: 6

                MaterialSymbol {
                    visible: root.actionIcon.length > 0
                    text: root.actionIcon
                    iconSize: 16
                    color: SettingsTokens.fg
                }

                StyledText {
                    text: root.actionLabel
                    color: SettingsTokens.fg
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                }
            }

            MouseArea {
                id: actionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.actionClicked()
            }
        }
    }
}
