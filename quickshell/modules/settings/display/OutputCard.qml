import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    required property var displayState
    required property var output

    readonly property var draft: (displayState.revision, displayState.draftFor(output.name))

    Layout.fillWidth: true
    implicitHeight: cardColumn.implicitHeight + 34
    radius: 14
    color: "#242424"
    border.width: displayState.outputChanged(output) ? 1 : 0
    border.color: displayState.outputChanged(output) ? TuiStyle.accent : "transparent"

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
                    text: displayState.displayName(output)
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
                displayFormatter: root.displayState.formatModeLabel
                currentValue: draft.mode
                onSelected: value => root.displayState.setDraftValue(root.output.name, "mode", value)
            }

            SettingCombo {
                Layout.fillWidth: true
                label: "Rotation"
                model: [0, 1, 2, 3, 4, 5, 6, 7]
                displayFormatter: root.displayState.transformLabel
                currentValue: draft.transform
                onSelected: value => root.displayState.setDraftValue(root.output.name, "transform", value)
            }

            SettingCombo {
                Layout.fillWidth: true
                label: "Scale"
                model: root.displayState.scaleChoices(draft.scale)
                displayFormatter: root.displayState.scaleLabel
                currentValue: Number(draft.scale || 1)
                onSelected: value => root.displayState.setDraftValue(root.output.name, "scale", Number(value))
            }

            PositionEditor {
                Layout.fillWidth: true
                displayState: root.displayState
                output: root.output
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.displayState.modeIsLowRefresh(draft.mode)
            text: "This refresh rate can make cursor movement and animations feel choppy. Prefer 60Hz or higher when available."
            color: TuiStyle.warning
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Item { Layout.fillWidth: true }

            SmallButton {
                text: "Reset"
                iconName: "undo"
                enabled: root.displayState.outputChanged(root.output)
                onClicked: {
                    const base = root.displayState.makeDraft(root.output);
                    root.displayState.setDraftValue(root.output.name, "mode", base.mode);
                    root.displayState.setDraftValue(root.output.name, "x", base.x);
                    root.displayState.setDraftValue(root.output.name, "y", base.y);
                    root.displayState.setDraftValue(root.output.name, "scale", base.scale);
                    root.displayState.setDraftValue(root.output.name, "transform", base.transform);
                }
            }

            SmallButton {
                text: "Apply"
                iconName: "check"
                enabled: root.displayState.outputChanged(root.output)
                primary: true
                onClicked: root.displayState.applyOutput(root.output.name)
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

            background: Rectangle {
                implicitHeight: 38
                color: "#1c1c1c"
                border.color: combo.visualFocus ? TuiStyle.accent : "#3a3a3a"
                border.width: 1
                radius: 8
            }

            contentItem: StyledText {
                leftPadding: 12
                rightPadding: 24
                text: combo.displayText
                color: "#f4f4f4"
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            indicator: MaterialSymbol {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: combo.popup.visible ? "arrow_drop_up" : "arrow_drop_down"
                iconSize: 20
                color: "#b0b0b0"
            }

            popup: Popup {
                y: combo.height + 4
                width: combo.width
                height: Math.min(320, listView.contentHeight + topPadding + bottomPadding)
                padding: 1

                contentItem: ListView {
                    id: listView
                    clip: true
                    model: combo.popup.visible ? combo.delegateModel : null
                    currentIndex: combo.highlightedIndex
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {
                        policy: listView.contentHeight > listView.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    }
                }

                background: Rectangle {
                    color: "#181818"
                    border.color: "#303030"
                    border.width: 1
                    radius: 8
                }
            }

            delegate: ItemDelegate {
                id: itemDelegate
                width: combo.width
                height: 36
                
                background: Rectangle {
                    color: itemDelegate.highlighted ? "#303030" : "transparent"
                }

                contentItem: StyledText {
                    leftPadding: 12
                    text: modelData.label
                    color: itemDelegate.highlighted ? TuiStyle.accent : "#f4f4f4"
                    font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    component PositionEditor: ColumnLayout {
        id: posRoot
        required property var displayState
        required property var output
        readonly property var draft: (displayState.revision, displayState.draftFor(output.name))

        spacing: 8
        StyledText { text: "Position"; color: "#cfcfcf"; font.pixelSize: 13 }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            SpinBox {
                id: spinX
                Layout.fillWidth: true
                from: -20000
                to: 20000
                value: posRoot.draft.x
                editable: true
                onValueModified: posRoot.displayState.setDraftValue(posRoot.output.name, "x", value)

                background: Rectangle {
                    implicitHeight: 38
                    color: "#1c1c1c"
                    border.color: spinX.activeFocus ? TuiStyle.accent : "#3a3a3a"
                    border.width: 1
                    radius: 8
                }

                contentItem: TextInput {
                    text: spinX.displayText
                    color: "#f4f4f4"
                    font.pixelSize: 13
                    font.family: Config.options.appearance.fonts.main
                    horizontalAlignment: Qt.AlignHCenter
                    verticalAlignment: Qt.AlignVCenter
                    readOnly: !spinX.editable
                    validator: spinX.validator
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    selectionColor: TuiStyle.accent
                    selectedTextColor: "#111111"
                }

                down.indicator: Rectangle {
                    x: 1
                    y: 1
                    height: parent.height - 2
                    width: 28
                    color: spinX.down.pressed ? "#303030" : "transparent"
                    radius: 7
                    StyledText {
                        anchors.centerIn: parent
                        text: "−"
                        color: spinX.down.hovered ? TuiStyle.accent : "#cfcfcf"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }
                }

                up.indicator: Rectangle {
                    x: parent.width - width - 1
                    y: 1
                    height: parent.height - 2
                    width: 28
                    color: spinX.up.pressed ? "#303030" : "transparent"
                    radius: 7
                    StyledText {
                        anchors.centerIn: parent
                        text: "+"
                        color: spinX.up.hovered ? TuiStyle.accent : "#cfcfcf"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }
                }
            }
            SpinBox {
                id: spinY
                Layout.fillWidth: true
                from: -20000
                to: 20000
                value: posRoot.draft.y
                editable: true
                onValueModified: posRoot.displayState.setDraftValue(posRoot.output.name, "y", value)

                background: Rectangle {
                    implicitHeight: 38
                    color: "#1c1c1c"
                    border.color: spinY.activeFocus ? TuiStyle.accent : "#3a3a3a"
                    border.width: 1
                    radius: 8
                }

                contentItem: TextInput {
                    text: spinY.displayText
                    color: "#f4f4f4"
                    font.pixelSize: 13
                    font.family: Config.options.appearance.fonts.main
                    horizontalAlignment: Qt.AlignHCenter
                    verticalAlignment: Qt.AlignVCenter
                    readOnly: !spinY.editable
                    validator: spinY.validator
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    selectionColor: TuiStyle.accent
                    selectedTextColor: "#111111"
                }

                down.indicator: Rectangle {
                    x: 1
                    y: 1
                    height: parent.height - 2
                    width: 28
                    color: spinY.down.pressed ? "#303030" : "transparent"
                    radius: 7
                    StyledText {
                        anchors.centerIn: parent
                        text: "−"
                        color: spinY.down.hovered ? TuiStyle.accent : "#cfcfcf"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }
                }

                up.indicator: Rectangle {
                    x: parent.width - width - 1
                    y: 1
                    height: parent.height - 2
                    width: 28
                    color: spinY.up.pressed ? "#303030" : "transparent"
                    radius: 7
                    StyledText {
                        anchors.centerIn: parent
                        text: "+"
                        color: spinY.up.hovered ? TuiStyle.accent : "#cfcfcf"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }
                }
            }
        }
    }
}
