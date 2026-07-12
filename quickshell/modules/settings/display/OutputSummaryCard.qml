import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    required property var displayState
    required property var output
    signal openAdvanced()

    readonly property var draft: (displayState.revision, displayState.draftFor(output.name))

    Layout.fillWidth: true
    implicitHeight: cardColumn.implicitHeight + 24
    radius: 14
    color: "#242424"
    border.width: displayState.outputChanged(output) ? 1 : 0
    border.color: displayState.outputChanged(output) ? TuiStyle.accent : "transparent"

    ColumnLayout {
        id: cardColumn
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialSymbol {
                text: draft.disabled ? "desktop_access_disabled" : "desktop_windows"
                iconSize: 22
                color: draft.disabled ? "#888888" : TuiStyle.accent
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: displayState.displayName(output)
                    color: "#f4f4f4"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: displayState.formatModeLabel(draft.mode)
                    color: "#9f9f9f"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            StyledText {
                text: output.focused ? "Focused" : `${draft.x}, ${draft.y}`
                color: output.focused ? TuiStyle.accent : "#a8a8a8"
                font.pixelSize: 12
            }

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 10
                color: advMouse.containsMouse ? "#363636" : "transparent"
                border.width: 1
                border.color: advMouse.containsMouse ? "#555555" : "transparent"

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "tune"
                    iconSize: 18
                    color: advMouse.containsMouse ? "#f4f4f4" : "#9f9f9f"
                }

                MouseArea {
                    id: advMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openAdvanced()
                }
            }
        }
    }
}