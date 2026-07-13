import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings

Rectangle {
    id: root

    required property var displayState
    required property var output

    readonly property var draft: (displayState.revision, displayState.draftFor(output.name))

    Layout.fillWidth: true
    implicitHeight: cardColumn.implicitHeight + 20
    radius: SettingsTokens.radius
    color: SettingsTokens.card
    border.width: 1
    border.color: displayState.outputChanged(output) ? SettingsTokens.accent : SettingsTokens.buttonBorder

    ColumnLayout {
        id: cardColumn
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            MaterialSymbol {
                text: draft.disabled ? "desktop_access_disabled" : "desktop_windows"
                iconSize: 20
                color: draft.disabled ? SettingsTokens.muted : SettingsTokens.accent
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: displayState.displayName(output)
                    color: SettingsTokens.fg
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: output.name + (output.make || output.model ? `  ${output.make} ${output.model}` : "")
                    color: SettingsTokens.muted
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            StyledText {
                text: output.focused ? "Focused" : `${draft.x}, ${draft.y}`
                color: output.focused ? SettingsTokens.accent : SettingsTokens.muted
                font.pixelSize: 11
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: root.width > 720 ? 2 : 1
            columnSpacing: 12
            rowSpacing: 8

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
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

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

        Layout.preferredHeight: 28
        Layout.preferredWidth: label.implicitWidth + 36
        radius: SettingsTokens.radius
        color: !enabled ? SettingsTokens.bg : primary ? SettingsTokens.buttonActive : (mouse.containsMouse ? SettingsTokens.buttonHover : SettingsTokens.button)
        border.width: 1
        border.color: primary ? SettingsTokens.accent : SettingsTokens.buttonBorder
        opacity: enabled ? 1 : 0.45

        Row {
            anchors.centerIn: parent
            spacing: 5
            MaterialSymbol {
                text: button.iconName
                iconSize: 14
                color: primary ? SettingsTokens.accent : SettingsTokens.fg
            }
            StyledText {
                id: label
                text: button.text
                color: SettingsTokens.fg
                font.pixelSize: 12
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

        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            StyledText { text: sliderRoot.label; color: SettingsTokens.fg; font.pixelSize: 12; Layout.fillWidth: true }
            StyledText { text: sliderRoot.valueLabel; color: SettingsTokens.muted; font.pixelSize: 12 }
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
                height: 4
                radius: 2
                color: SettingsTokens.line

                Rectangle {
                    width: innerSlider.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: SettingsTokens.accent
                }
            }

            handle: Rectangle {
                x: innerSlider.visualPosition * (innerSlider.width - width)
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                height: 12
                radius: 6
                color: SettingsTokens.fg
                border.width: 1.5
                border.color: innerSlider.pressed ? SettingsTokens.accent : SettingsTokens.buttonBorder
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

        spacing: 4
        StyledText { text: comboRoot.label; color: SettingsTokens.fg; font.pixelSize: 12 }
        ComboBox {
            id: combo
            Layout.fillWidth: true
            model: comboRoot.model.map(value => ({ value, label: comboRoot.displayFormatter(value) }))
            textRole: "label"
            valueRole: "value"
            currentIndex: Math.max(0, comboRoot.model.findIndex(value => String(value) === String(comboRoot.currentValue)))
            onActivated: comboRoot.selected(currentValue)

            background: Rectangle {
                implicitHeight: 30
                color: SettingsTokens.button
                border.color: combo.visualFocus ? SettingsTokens.accent : SettingsTokens.buttonBorder
                border.width: 1
                radius: SettingsTokens.radius
            }

            contentItem: StyledText {
                leftPadding: 10
                rightPadding: 20
                text: combo.displayText
                color: SettingsTokens.fg
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            indicator: MaterialSymbol {
                text: "arrow_drop_down"
                iconSize: 18
                color: SettingsTokens.muted
                x: combo.width - width - 8
                y: (combo.height - height) / 2
            }

            popup: Popup {
                y: combo.height + 2
                width: combo.width
                implicitHeight: contentItem.implicitHeight
                padding: 1

                contentItem: ListView {
                    clip: true
                    implicitHeight: contentHeight
                    model: combo.popup.visible ? combo.delegateModel : null
                    currentIndex: combo.highlightedIndex

                    ScrollIndicator.vertical: ScrollIndicator { }
                }

                background: Rectangle {
                    color: SettingsTokens.card
                    border.color: SettingsTokens.buttonBorder
                    border.width: 1
                    radius: SettingsTokens.radius
                }
            }

            delegate: ItemDelegate {
                id: delegateRoot
                width: combo.width
                height: 30
                highlighted: combo.highlightedIndex === index

                background: Rectangle {
                    color: delegateRoot.highlighted ? SettingsTokens.buttonHover : "transparent"
                    radius: SettingsTokens.radius
                }

                contentItem: StyledText {
                    leftPadding: 10
                    text: label
                    color: delegateRoot.highlighted ? SettingsTokens.fg : SettingsTokens.muted
                    font.pixelSize: 12
                    elide: Text.ElideRight
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

        spacing: 4
        StyledText { text: "Position"; color: SettingsTokens.fg; font.pixelSize: 12 }
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
                    implicitHeight: 30
                    color: SettingsTokens.button
                    border.color: spinX.activeFocus ? SettingsTokens.accent : SettingsTokens.buttonBorder
                    border.width: 1
                    radius: SettingsTokens.radius
                }

                contentItem: TextInput {
                    text: spinX.displayText
                    color: SettingsTokens.fg
                    font.pixelSize: 12
                    font.family: Config.options.appearance.fonts.main
                    horizontalAlignment: Qt.AlignHCenter
                    verticalAlignment: Qt.AlignVCenter
                    readOnly: !spinX.editable
                    validator: spinX.validator
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    selectionColor: SettingsTokens.accent
                    selectedTextColor: "#111111"
                }

                down.indicator: Rectangle {
                    x: 1
                    y: 1
                    height: parent.height - 2
                    width: 24
                    color: spinX.down.pressed ? SettingsTokens.buttonHover : "transparent"
                    radius: SettingsTokens.radius - 1
                    StyledText {
                        anchors.centerIn: parent
                        text: "−"
                        color: spinX.down.hovered ? SettingsTokens.accent : SettingsTokens.fg
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }
                }

                up.indicator: Rectangle {
                    x: parent.width - width - 1
                    y: 1
                    height: parent.height - 2
                    width: 24
                    color: spinX.up.pressed ? SettingsTokens.buttonHover : "transparent"
                    radius: SettingsTokens.radius - 1
                    StyledText {
                        anchors.centerIn: parent
                        text: "+"
                        color: spinX.up.hovered ? SettingsTokens.accent : SettingsTokens.fg
                        font.pixelSize: 13
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
                    implicitHeight: 30
                    color: SettingsTokens.button
                    border.color: spinY.activeFocus ? SettingsTokens.accent : SettingsTokens.buttonBorder
                    border.width: 1
                    radius: SettingsTokens.radius
                }

                contentItem: TextInput {
                    text: spinY.displayText
                    color: SettingsTokens.fg
                    font.pixelSize: 12
                    font.family: Config.options.appearance.fonts.main
                    horizontalAlignment: Qt.AlignHCenter
                    verticalAlignment: Qt.AlignVCenter
                    readOnly: !spinY.editable
                    validator: spinY.validator
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    selectionColor: SettingsTokens.accent
                    selectedTextColor: "#111111"
                }

                down.indicator: Rectangle {
                    x: 1
                    y: 1
                    height: parent.height - 2
                    width: 24
                    color: spinY.down.pressed ? SettingsTokens.buttonHover : "transparent"
                    radius: SettingsTokens.radius - 1
                    StyledText {
                        anchors.centerIn: parent
                        text: "−"
                        color: spinY.down.hovered ? SettingsTokens.accent : SettingsTokens.fg
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }
                }

                up.indicator: Rectangle {
                    x: parent.width - width - 1
                    y: 1
                    height: parent.height - 2
                    width: 24
                    color: spinY.up.pressed ? SettingsTokens.buttonHover : "transparent"
                    radius: SettingsTokens.radius - 1
                    StyledText {
                        anchors.centerIn: parent
                        text: "+"
                        color: spinY.up.hovered ? SettingsTokens.accent : SettingsTokens.fg
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }
                }
            }
        }
    }
}
