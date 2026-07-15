import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property string label: ""
    property string description: ""
    property string currentValue: ""
    property var options: []
    property int dropdownWidth: 180
    property bool controlled: false
    signal valueChanged(string value)

    Layout.fillWidth: true
    implicitHeight: 56
    radius: SettingsTokens.radius
    color: ddRowMouse.containsMouse ? SettingsTokens.cardHover : "transparent"

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
            id: ddButton
            Layout.preferredWidth: root.dropdownWidth
            Layout.preferredHeight: 36
            radius: SettingsTokens.radius
            color: ddBtnMouse.containsMouse ? SettingsTokens.buttonHover : SettingsTokens.button
            border.width: 1
            border.color: dropdownOpen ? SettingsTokens.accent : SettingsTokens.buttonBorder
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
                    color: SettingsTokens.fg
                    font.pixelSize: Appearance.font.pixelSize.small
                    elide: Text.ElideRight
                }

                MaterialSymbol {
                    text: ddButton.dropdownOpen ? "expand_less" : "expand_more"
                    iconSize: 18
                    color: SettingsTokens.muted
                }
            }

            MouseArea {
                id: ddBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    if (root.options && root.options.length > 0) {
                        ddButton.dropdownOpen = !ddButton.dropdownOpen
                    }
                }
            }

            Popup {
                id: ddPopup
                y: ddButton.height + 4
                width: root.dropdownWidth
                height: Math.min(300, (root.options ? root.options.length : 0) * 34 + 8)
                visible: ddButton.dropdownOpen && root.options && root.options.length > 0
                padding: 0

                background: Rectangle {
                    radius: SettingsTokens.radius
                    color: SettingsTokens.panel
                    border.width: 1
                    border.color: SettingsTokens.line
                }

                onClosed: ddButton.dropdownOpen = false

                ListView {
                    id: ddOptList
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.options
                    ScrollBar.vertical: StyledScrollBar {}

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: ddOptList.width
                        height: 34
                        radius: SettingsTokens.radius
                        color: ddOptMouse.containsMouse ? SettingsTokens.cardHover
                            : (modelData.value === root.currentValue ? SettingsTokens.accentSoft : "transparent")

                        StyledText {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: Text.AlignVCenter
                            text: modelData.label
                            color: SettingsTokens.fg
                            font.pixelSize: Appearance.font.pixelSize.small
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: ddOptMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (!root.controlled)
                                    root.currentValue = modelData.value
                                root.valueChanged(modelData.value)
                                ddPopup.close()
                            }
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        id: ddRowMouse
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.ArrowCursor
    }
}
