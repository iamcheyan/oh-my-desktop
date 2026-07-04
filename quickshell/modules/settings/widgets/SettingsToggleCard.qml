import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * SettingsToggleCard — a card with a toggle that expands/collapses
 * optional content when the toggle is on.
 */
Rectangle {
    id: root
    property string title: ""
    property string description: ""
    property string iconName: ""
    property bool checked: false
    signal toggled()

    Layout.fillWidth: true
    implicitHeight: cardColumn.implicitHeight + 24
    radius: TuiStyle.radius
    color: TuiStyle.surfaceRaised
    border.width: 1
    border.color: TuiStyle.line

    ColumnLayout {
        id: cardColumn
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialSymbol {
                visible: root.iconName.length > 0
                Layout.preferredWidth: visible ? 22 : 0
                text: root.iconName
                iconSize: 19
                color: TuiStyle.muted
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: root.title
                    color: TuiStyle.fg
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                StyledText {
                    visible: root.description.length > 0
                    Layout.fillWidth: true
                    text: root.description
                    color: TuiStyle.dim
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                Layout.preferredWidth: 46
                Layout.preferredHeight: 26
                radius: height / 2
                color: root.checked ? TuiStyle.accent : "#5a5a5a"

                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.checked ? parent.width - width - 3 : 3
                    color: root.checked ? "#111111" : "#dedede"
                    Behavior on x { NumberAnimation { duration: 110 } }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.toggled()
                }
            }
        }

        // Expandable content slot — children go here
        ColumnLayout {
            id: contentSlot
            Layout.fillWidth: true
            visible: root.checked
            spacing: 8
        }
    }
}