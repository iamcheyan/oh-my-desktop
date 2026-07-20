import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings

Rectangle {
    id: root

    required property var displayState
    required property var output
    property bool selected: false
    signal clicked()

    readonly property var draft: (displayState.revision, displayState.draftFor(output.name))

    Layout.fillWidth: true
    implicitHeight: 64
    radius: SettingsTokens.radius
    color: selected ? SettingsTokens.accentSoft : (mouse.containsMouse ? SettingsTokens.cardHover : "transparent")
    border.width: selected ? 1 : 0
    border.color: selected ? SettingsTokens.accent : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        MaterialSymbol {
            text: "desktop_windows"
            iconSize: 22
            color: root.selected ? SettingsTokens.accent : SettingsTokens.muted
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: root.displayState.displayName(root.output)
                color: SettingsTokens.fg
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: `${root.output.name}  ·  ${root.displayState.formatModeLabel(root.draft.mode)}  ·  ${root.displayState.scaleLabel(root.draft.scale)}`
                color: SettingsTokens.muted
                font.pixelSize: Appearance.font.pixelSize.smaller
                elide: Text.ElideRight
            }
        }

        StyledText {
            visible: root.output.focused
            text: "Focused"
            color: SettingsTokens.accent
            font.pixelSize: Appearance.font.pixelSize.smaller
        }

        MaterialSymbol {
            text: "chevron_right"
            iconSize: 18
            color: SettingsTokens.dim
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
