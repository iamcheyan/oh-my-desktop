import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    Layout.fillWidth: true
    implicitHeight: 56
    color: "transparent"

    property string label: ""
    property string description: ""
    property alias value: slider.value
    property alias from: slider.from
    property alias to: slider.to
    property alias stepSize: slider.stepSize
    property string valueSuffix: ""
    property var formatValue: null // Optional formatter function

    signal moved()

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 14

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            StyledText {
                text: root.label
                color: SettingsTokens.fg
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {
                text: root.description
                color: SettingsTokens.dim
                font.pixelSize: Appearance.font.pixelSize.smaller
                visible: root.description.length > 0
                elide: Text.ElideRight
            }
        }

        RowLayout {
            Layout.fillWidth: false
            Layout.preferredWidth: 190
            Layout.preferredHeight: 36
            spacing: 10

            SettingsSlider {
                id: slider
                Layout.fillWidth: true
                onMoved: root.moved()
            }

            StyledText {
                Layout.preferredWidth: 42
                text: root.formatValue ? root.formatValue(slider.value) : `${Math.round(slider.value)}${root.valueSuffix}`
                color: SettingsTokens.fg
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
