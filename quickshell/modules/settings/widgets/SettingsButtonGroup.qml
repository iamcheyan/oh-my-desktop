import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * SettingsButtonGroup — segmented button group for selecting one option
 * from a list. Each button is a fixed-width pill.
 */
RowLayout {
    id: root
    property var options: []           // array of {value, label}
    property string currentValue: ""
    property int buttonHeight: 34
    signal valueChanged(string value)

    spacing: 0

    Repeater {
        model: root.options
        delegate: Rectangle {
            required property var modelData
            required property int index
            Layout.preferredHeight: root.buttonHeight
            Layout.fillWidth: true
            radius: {
                const r = TuiStyle.miniRadius
                if (root.options.length === 1) return r
                if (index === 0) return r
                if (index === root.options.length - 1) return r
                return 0
            }
            color: modelData.value === root.currentValue
                ? TuiStyle.selection
                : (btnMouse.containsMouse ? TuiStyle.surfaceHover : TuiStyle.control)
            border.width: 1
            border.color: modelData.value === root.currentValue
                ? TuiStyle.controlActiveBorder
                : TuiStyle.line

            StyledText {
                anchors.centerIn: parent
                text: modelData.label
                color: TuiStyle.fg
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: modelData.value === root.currentValue ? Font.Medium : Font.Normal
                elide: Text.ElideRight
            }

            MouseArea {
                id: btnMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    root.currentValue = modelData.value
                    root.valueChanged(modelData.value)
                }
            }
        }
    }
}