import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * SettingsDropdownRow — a row with label/description on the left and a
 * dropdown on the right. Uses TuiStyle tokens for visual consistency.
 */
Rectangle {
    id: root
    property string label: ""
    property string description: ""
    property string currentValue: ""
    property var options: []          // array of {value, label}
    property int dropdownWidth: 180
    signal valueChanged(string value)

    Layout.fillWidth: true
    implicitHeight: 56
    radius: TuiStyle.miniRadius
    color: rowMouse.containsMouse ? TuiStyle.surfaceHover : "transparent"

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
            Layout.preferredWidth: root.dropdownWidth
            Layout.preferredHeight: 36
            radius: TuiStyle.miniRadius
            color: dropdownMouse.containsMouse ? TuiStyle.controlHover : TuiStyle.control
            border.width: 1
            border.color: dropdownOpen ? TuiStyle.controlActiveBorder : TuiStyle.line

            property bool dropdownOpen: false

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 6

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        for (const opt of root.options) {
                            if (opt.value === root.currentValue) return opt.label
                        }
                        return root.currentValue
                    }
                    color: TuiStyle.fg
                    font.pixelSize: Appearance.font.pixelSize.small
                    elide: Text.ElideRight
                }

                MaterialSymbol {
                    text: root.dropdownOpen ? "expand_less" : "expand_more"
                    iconSize: 18
                    color: TuiStyle.muted
                }
            }

            MouseArea {
                id: dropdownMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.dropdownOpen = !root.dropdownOpen
            }

            Popup {
                id: dropdownPopup
                y: parent.height + 4
                width: root.dropdownWidth
                height: Math.min(300, optionColumn.implicitHeight + 8)
                visible: root.dropdownOpen
                onClosed: root.dropdownOpen = false

                background: Rectangle {
                    radius: TuiStyle.miniRadius
                    color: TuiStyle.bg
                    border.width: 1
                    border.color: TuiStyle.line
                }

                onOpened: root.dropdownOpen = true
                onClosed: root.dropdownOpen = false

                ColumnLayout {
                    id: optionColumn
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 0

                    Repeater {
                        model: root.options
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            radius: TuiStyle.miniRadius
                            color: optMouse.containsMouse ? TuiStyle.surfaceHover
                                : (modelData.value === root.currentValue ? TuiStyle.selection : "transparent")

                            StyledText {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                verticalAlignment: Text.AlignVCenter
                                text: modelData.label
                                color: TuiStyle.fg
                                font.pixelSize: Appearance.font.pixelSize.small
                            }

                            MouseArea {
                                id: optMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.currentValue = modelData.value
                                    root.valueChanged(modelData.value)
                                    dropdownPopup.close()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        acceptedButtons: Qt.NoButton
    }
}