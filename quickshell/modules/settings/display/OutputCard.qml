import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    required property var state
    required property var output

    readonly property var draft: (state.revision, state.draftFor(output.name))

    Layout.fillWidth: true
    implicitHeight: cardColumn.implicitHeight + 34
    radius: 14
    color: "#242424"
    border.width: state.outputChanged(output) ? 1 : 0
    border.color: state.outputChanged(output) ? TuiStyle.accent : "transparent"

    ColumnLayout {
        id: cardColumn
        anchors.fill: parent
        anchors.margins: 17
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialSymbol {
                text: draft.disabled ? "desktop_access_disabled" : "desktop_windows"
                iconSize: 24
                color: draft.disabled ? "#888888" : TuiStyle.accent
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: state.displayName(output)
                    color: "#f4f4f4"
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: output.name + (output.make || output.model ? `  ${output.make} ${output.model}` : "")
                    color: "#9f9f9f"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            StyledText {
                text: output.focused ? "Focused" : `${draft.x}, ${draft.y}`
                color: output.focused ? TuiStyle.accent : "#a8a8a8"
                font.pixelSize: 13
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: root.width > 720 ? 2 : 1
            columnSpacing: 16
            rowSpacing: 12

            SettingCombo {
                Layout.fillWidth: true
                label: "Resolution & refresh"
                model: output.modes.length > 0 ? output.modes : [draft.mode]
                displayFormatter: root.state.formatModeLabel
                currentValue: draft.mode
                onSelected: value => root.state.setDraftValue(root.output.name, "mode", value)
            }

            SettingCombo {
                Layout.fillWidth: true
                label: "Rotation"
                model: [0, 1, 2, 3, 4, 5, 6, 7]
                displayFormatter: root.state.transformLabel
                currentValue: draft.transform
                onSelected: value => root.state.setDraftValue(root.output.name, "transform", value)
            }

            SettingSlider {
                Layout.fillWidth: true
                label: "Scale"
                from: 0.75
                to: 3
                stepSize: 0.05
                value: draft.scale
                valueLabel: root.state.scaleLabel(draft.scale)
                onMovedValue: value => root.state.setDraftValue(root.output.name, "scale", Number(value.toFixed(2)))
            }

            PositionEditor {
                Layout.fillWidth: true
                state: root.state
                output: root.output
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Item { Layout.fillWidth: true }

            SmallButton {
                text: "Reset"
                iconName: "undo"
                enabled: root.state.outputChanged(root.output)
                onClicked: {
                    const base = root.state.makeDraft(root.output);
                    root.state.setDraftValue(root.output.name, "mode", base.mode);
                    root.state.setDraftValue(root.output.name, "x", base.x);
                    root.state.setDraftValue(root.output.name, "y", base.y);
                    root.state.setDraftValue(root.output.name, "scale", base.scale);
                    root.state.setDraftValue(root.output.name, "transform", base.transform);
                }
            }

            SmallButton {
                text: "Apply"
                iconName: "check"
                enabled: root.state.outputChanged(root.output)
                primary: true
                onClicked: root.state.applyOutput(root.output.name)
            }
        }
    }

    component SmallButton: Rectangle {
        id: button
        property string text: ""
        property string iconName: ""
        property bool primary: false
        signal clicked

        Layout.preferredHeight: 36
        Layout.preferredWidth: label.implicitWidth + 54
        radius: 12
        color: !enabled ? "#202020" : primary ? TuiStyle.accentWash(TuiStyle.accent) : (mouse.containsMouse ? "#363636" : "#2c2c2c")
        border.width: 1
        border.color: primary ? TuiStyle.accent : "#555555"
        opacity: enabled ? 1 : 0.45

        Row {
            anchors.centerIn: parent
            spacing: 7
            MaterialSymbol {
                text: button.iconName
                iconSize: 17
                color: primary ? TuiStyle.accent : "#f4f4f4"
            }
            StyledText {
                id: label
                text: button.text
                color: "#f4f4f4"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: button.enabled
            onClicked: button.clicked()
        }
    }

    component SettingSlider: ColumnLayout {
        id: sliderRoot
        property string label: ""
        property real from: 0
        property real to: 1
        property real stepSize: 0.1
        property real value: 0
        property string valueLabel: String(value)
        signal movedValue(real value)

        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            StyledText { text: sliderRoot.label; color: "#cfcfcf"; font.pixelSize: 13; Layout.fillWidth: true }
            StyledText { text: sliderRoot.valueLabel; color: "#a8a8a8"; font.pixelSize: 13 }
        }
        Slider {
            id: innerSlider
            Layout.fillWidth: true
            from: sliderRoot.from
            to: sliderRoot.to
            stepSize: sliderRoot.stepSize
            value: sliderRoot.value
            onMoved: sliderRoot.movedValue(value)

            background: Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: 0
                width: innerSlider.width
                height: 6
                radius: 3
                color: "#454545"

                Rectangle {
                    width: innerSlider.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: TuiStyle.accent
                }
            }

            handle: Rectangle {
                x: innerSlider.visualPosition * (innerSlider.width - width)
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                radius: 8
                color: "#f4f4f4"
                border.width: 2
                border.color: innerSlider.pressed ? TuiStyle.accent : "#4a4a4a"
                Behavior on border.color { ColorAnimation { duration: 100 } }
            }
        }
    }

    component SettingCombo: ColumnLayout {
        id: comboRoot
        property string label: ""
        property var model: []
        property var displayFormatter: function(value) { return String(value); }
        property var currentValue
        signal selected(var value)

        spacing: 8
        StyledText { text: comboRoot.label; color: "#cfcfcf"; font.pixelSize: 13 }
        ComboBox {
            id: combo
            Layout.fillWidth: true
            model: comboRoot.model.map(value => ({ value, label: comboRoot.displayFormatter(value) }))
            textRole: "label"
            valueRole: "value"
            currentIndex: Math.max(0, comboRoot.model.findIndex(value => String(value) === String(comboRoot.currentValue)))
            onActivated: comboRoot.selected(currentValue)
        }
    }

    component PositionEditor: ColumnLayout {
        id: posRoot
        required property var state
        required property var output
        readonly property var draft: (state.revision, state.draftFor(output.name))

        spacing: 8
        StyledText { text: "Position"; color: "#cfcfcf"; font.pixelSize: 13 }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            SpinBox {
                Layout.fillWidth: true
                from: -20000
                to: 20000
                value: posRoot.draft.x
                editable: true
                onValueModified: posRoot.state.setDraftValue(posRoot.output.name, "x", value)
            }
            SpinBox {
                Layout.fillWidth: true
                from: -20000
                to: 20000
                value: posRoot.draft.y
                editable: true
                onValueModified: posRoot.state.setDraftValue(posRoot.output.name, "y", value)
            }
        }
    }
}
