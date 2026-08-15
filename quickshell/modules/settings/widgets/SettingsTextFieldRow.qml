pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property string label: ""
    property string description: ""
    property string text: ""
    property string placeholder: ""
    property int fieldWidth: 200
    property int echoMode: TextInput.Normal
    signal textEdited(string newText)

    Layout.fillWidth: true
    implicitHeight: 56
    radius: SettingsTokens.radius
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
                color: SettingsTokens.fg
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
            }

            StyledText {
                visible: root.description.length > 0
                Layout.fillWidth: true
                text: root.description
                color: SettingsTokens.dim
                font.pixelSize: Appearance.font.pixelSize.smaller
                elide: Text.ElideRight
            }
        }

        Rectangle {
            Layout.preferredWidth: root.fieldWidth
            Layout.preferredHeight: 36
            radius: SettingsTokens.radius
            color: SettingsTokens.button
            border.width: 1
            border.color: tfInput.activeFocus ? SettingsTokens.accent : SettingsTokens.buttonBorder

            TextInput {
                id: tfInput
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: Text.AlignVCenter
                text: root.text
                echoMode: root.echoMode
                color: SettingsTokens.fg
                font.pixelSize: Appearance.font.pixelSize.small
                clip: true

                onTextEdited: {
                    root.text = tfInput.text
                    root.textEdited(tfInput.text)
                }
            }
        }
    }
}
