import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: overlay

    required property var settingsRoot
    anchors.fill: parent
    visible: overlay.settingsRoot.keyremapEditingPreset !== ""
    z: 55

    Rectangle {
        anchors.fill: parent
        color: "#050505"
        opacity: 0.72

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (keyEditorPopup.opened)
                    keyEditorPopup.close()
            }
        }
    }

    Rectangle {
        width: Math.min(420, parent.width - 64)
        height: keyEditorContent.implicitHeight + 48
        anchors.centerIn: parent
        radius: SettingsTokens.roundRadius
        color: SettingsTokens.card
        border.width: 1
        border.color: SettingsTokens.accent

        ColumnLayout {
            id: keyEditorContent
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                MaterialSymbol {
                    text: "edit"
                    iconSize: 22
                    color: SettingsTokens.accent
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        const preset = KeyboardRemap.presetChoice(overlay.settingsRoot.keyremapEditingPreset)
                        return preset ? `Edit: ${preset.label}` : ""
                    }
                    color: SettingsTokens.fg
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: SettingsTokens.radius
                    color: closeBtnMouse.containsMouse ? SettingsTokens.buttonHover : "transparent"

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: 18
                        color: SettingsTokens.muted
                    }

                    MouseArea {
                        id: closeBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            keyEditorPopup.close()
                            overlay.settingsRoot.keyremapEditingPreset = ""
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: {
                    const preset = KeyboardRemap.presetChoice(overlay.settingsRoot.keyremapEditingPreset)
                    if (!preset)
                        return ""
                    const current = KeyboardRemap.presetOverride(KeyboardRemap.selectedDeviceId, overlay.settingsRoot.keyremapEditingPreset)
                    const target = current.length > 0 ? current : preset.remaps[0].to
                    return `Source: ${preset.remaps[0].from}    Target: ${target}`
                }
                color: SettingsTokens.muted
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            // Key picker dropdown
            Rectangle {
                id: keyEditorTargetBox
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: SettingsTokens.radius
                color: keyEditorMouse.containsMouse ? SettingsTokens.buttonHover : SettingsTokens.panel
                border.width: 1
                border.color: keyEditorPopup.opened ? SettingsTokens.accent : SettingsTokens.line

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 10

                    StyledText {
                        text: "Target:"
                        color: SettingsTokens.dim
                        font.pixelSize: Appearance.font.pixelSize.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            const current = KeyboardRemap.presetOverride(KeyboardRemap.selectedDeviceId, overlay.settingsRoot.keyremapEditingPreset)
                            const preset = KeyboardRemap.presetChoice(overlay.settingsRoot.keyremapEditingPreset)
                            return current.length > 0 ? current : (preset?.remaps?.[0]?.to ?? "")
                        }
                        color: SettingsTokens.fg
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    MaterialSymbol {
                        text: keyEditorPopup.opened ? "expand_less" : "expand_more"
                        iconSize: 20
                        color: SettingsTokens.muted
                    }
                }

                MouseArea {
                    id: keyEditorMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (keyEditorPopup.opened)
                            keyEditorPopup.close()
                        else
                            keyEditorPopup.open()
                    }
                }

                Popup {
                    id: keyEditorPopup
                    y: keyEditorTargetBox.height + 4
                    width: keyEditorTargetBox.width
                    height: Math.min(260, keyEditorList.contentHeight + 8)
                    padding: 4
                    closePolicy: Popup.CloseOnEscape

                    background: Rectangle {
                        radius: SettingsTokens.radius
                        color: SettingsTokens.panel
                        border.width: 1
                        border.color: SettingsTokens.line
                    }

                    contentItem: ListView {
                        id: keyEditorList
                        clip: true
                        model: KeyboardRemap.keyChoices
                        delegate: Rectangle {
                            required property string modelData
                            required property int index
                            width: keyEditorList.width
                            height: 34
                            radius: SettingsTokens.radius
                            readonly property string currentTarget: {
                                const o = KeyboardRemap.presetOverride(KeyboardRemap.selectedDeviceId, overlay.settingsRoot.keyremapEditingPreset)
                                if (o.length > 0) return o
                                return KeyboardRemap.presetChoice(overlay.settingsRoot.keyremapEditingPreset)?.remaps?.[0]?.to ?? ""
                            }
                            color: keyChoiceMouse.containsMouse
                                ? SettingsTokens.cardHover
                                : (modelData === currentTarget ? SettingsTokens.accentSoft : "transparent")

                            StyledText {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 10
                                text: modelData
                                color: SettingsTokens.fg
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: Appearance.font.pixelSize.small
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: keyChoiceMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    KeyboardRemap.setPresetOverride(KeyboardRemap.selectedDeviceId, overlay.settingsRoot.keyremapEditingPreset, modelData)
                                    keyEditorPopup.close()
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: SettingsTokens.radius
                    color: resetMouse.containsMouse ? SettingsTokens.buttonHover : SettingsTokens.button
                    border.width: 1
                    border.color: SettingsTokens.buttonBorder
                    opacity: KeyboardRemap.presetOverride(KeyboardRemap.selectedDeviceId, overlay.settingsRoot.keyremapEditingPreset).length > 0 ? 1 : 0.45

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        MaterialSymbol { text: "refresh"; iconSize: 16; color: SettingsTokens.fg }
                        StyledText { text: "Reset to default"; color: SettingsTokens.fg; font.pixelSize: Appearance.font.pixelSize.small }
                    }

                    MouseArea {
                        id: resetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: KeyboardRemap.presetOverride(KeyboardRemap.selectedDeviceId, overlay.settingsRoot.keyremapEditingPreset).length > 0
                        onClicked: KeyboardRemap.setPresetOverride(KeyboardRemap.selectedDeviceId, overlay.settingsRoot.keyremapEditingPreset, "")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: SettingsTokens.radius
                    color: doneMouse.containsMouse ? SettingsTokens.buttonActive : SettingsTokens.accent
                    border.width: 1
                    border.color: SettingsTokens.accent

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        MaterialSymbol { text: "check"; iconSize: 16; color: "#111111" }
                        StyledText { text: "Done"; color: "#111111"; font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.DemiBold }
                    }

                    MouseArea {
                        id: doneMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            keyEditorPopup.close()
                            overlay.settingsRoot.keyremapEditingPreset = ""
                        }
                    }
                }
            }
        }
    }
}
