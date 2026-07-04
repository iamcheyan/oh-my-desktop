import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * SettingsTextFieldRow — a row with label/description on the left and a
 * text input field on the right.
 */
Rectangle {
    id: root
    property string label: ""
    property string description: ""
    property string text: ""
    property string placeholder: ""
    property int fieldWidth: 200
    signal textEdited(string newText)

    Layout.fillWidth: true
    implicitHeight: 56
    radius: TuiStyle.miniRadius
    color: "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 14

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            StyledText {
                Layout.fillWidth: true
                text: root.label
                color: TuiStyle.fg
                font.pixelSize: Appearance.font.pixelSize.small
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
            Layout.preferredWidth: root.fieldWidth
            Layout.preferredHeight: 36
            radius: TuiStyle.miniRadius
            color: TuiStyle.control
            border.width: 1
            border.color: field.activeFocus ? TuiStyle.controlActiveBorder : TuiStyle.line

            TextInput {
                id: field
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: Text.AlignVCenter
                text: root.text
                color: TuiStyle.fg
                font.pixelSize: Appearance.font.pixelSize.small
                clip: true

                onTextEdited: {
                    root.text = field.text
                    root.textEdited(field.text)
                }
            }
        }
    }
}