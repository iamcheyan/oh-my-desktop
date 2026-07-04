import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * SettingsSliderCard — a card containing a slider with icon/title/description
 * header and a value display.
 */
Rectangle {
    id: root
    property string title: ""
    property string description: ""
    property string iconName: ""
    property real value: 0
    property real minimum: 0
    property real maximum: 100
    property real step: 1
    property string unit: ""
    real defaultValue: 0
    signal valueChanged(real newValue)

    Layout.fillWidth: true
    implicitHeight: sliderColumn.implicitHeight + 24
    radius: TuiStyle.radius
    color: TuiStyle.surfaceRaised
    border.width: 1
    border.color: TuiStyle.line

    ColumnLayout {
        id: sliderColumn
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

            StyledText {
                Layout.preferredWidth: 70
                horizontalAlignment: Text.AlignRight
                text: `${Math.round(root.value)}${root.unit}`
                color: TuiStyle.fg
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
            }
        }

        Slider {
            Layout.fillWidth: true
            from: root.minimum
            to: root.maximum
            value: root.value
            stepSize: root.step
            onMoved: {
                root.value = value
                root.valueChanged(value)
            }

            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: slider.availableWidth
                height: 6
                radius: 3
                color: TuiStyle.meterTrack

                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    radius: 3
                    color: TuiStyle.accent
                }
            }

            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: 18
                height: 18
                radius: 9
                color: TuiStyle.fg
                border.width: 2
                border.color: TuiStyle.accent
            }
        }
    }
}