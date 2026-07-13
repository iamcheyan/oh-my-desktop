import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.settings
import qs.modules.settings.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

PageBody {
    id: keyremapRoot

    required property var settingsRoot

    // ── Status card (always visible) ──

    SettingsCard {
        title: "Keyboard Remap"
        subtitle: KeyboardRemap.hasPendingChanges ? "Draft changes are waiting to be applied" : "Current keyd config matches this page"

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            SettingsStatusPill { label: KeyboardRemap.keydReady ? "keyd running" : "keyd not ready"; active: KeyboardRemap.keydReady; warning: !KeyboardRemap.keydReady }
            SettingsStatusPill { label: `${KeyboardRemap.devices.length} connected`; active: KeyboardRemap.devices.length > 0 }
            SettingsStatusPill {
                label: KeyboardRemap.hasPendingChanges ? "pending" : "applied"
                active: !KeyboardRemap.hasPendingChanges
                warning: KeyboardRemap.hasPendingChanges
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: "Select a keyboard to enable presets for it."
            color: SettingsTokens.muted
            font.pixelSize: Appearance.font.pixelSize.small
            wrapMode: Text.WordWrap
        }

        SettingsRow {
            visible: KeyboardRemap.lastError.length > 0
            iconName: "warning"
            label: "Apply error"
            description: KeyboardRemap.lastError
            valueColor: "#f07070"
        }

        ButtonRow {
            SettingsButton {
                label: KeyboardRemap.state === "setup" ? "Setup keyd" : "Recheck"
                iconName: KeyboardRemap.state === "setup" ? "download" : "refresh"
                onClicked: {
                    if (KeyboardRemap.state === "setup")
                        KeyboardRemap.setup();
                    else
                        KeyboardRemap.checkKeyd();
                }
            }
            SettingsButton {
                label: KeyboardRemap.applyInProgress ? "Applying..." : "Apply changes"
                iconName: "check"
                active: KeyboardRemap.hasPendingChanges
                enabledState: KeyboardRemap.hasPendingChanges && !KeyboardRemap.applyInProgress
                onClicked: keyremapRoot.settingsRoot.keyremapApplyConfirmOpen = true
            }
            SettingsButton {
                label: "Refresh"
                iconName: "refresh"
                onClicked: {
                    KeyboardRemap.refreshDevices();
                    KeyboardRemap.loadProfiles();
                    KeyboardRemap.checkKeyd();
                }
            }
        }
    }

    // ── Apply confirmation ──

    SettingsCard {
        visible: keyremapRoot.settingsRoot.keyremapApplyConfirmOpen && KeyboardRemap.hasPendingChanges
        title: "Apply keyboard remaps?"
        subtitle: "This writes /etc/keyd/omd.conf and restarts keyd"

        SettingsRow {
            iconName: "security"
            label: "Authorization required"
            description: `${KeyboardRemap.devices.length} keyboard${KeyboardRemap.devices.length === 1 ? "" : "s"}`
            value: "keyd"
            valueColor: SettingsTokens.accent
        }

        ButtonRow {
            SettingsButton {
                label: "Apply"
                iconName: "check"
                active: true
                enabledState: !KeyboardRemap.applyInProgress
                onClicked: {
                    keyremapRoot.settingsRoot.keyremapApplyConfirmOpen = false;
                    KeyboardRemap.apply();
                }
            }
            SettingsButton {
                label: "Cancel"
                iconName: "close"
                enabledState: !KeyboardRemap.applyInProgress
                onClicked: keyremapRoot.settingsRoot.keyremapApplyConfirmOpen = false
            }
        }
    }

    // ══ TOP-LEVEL: Keyboard list ══

    SettingsCard {
        visible: !keyremapRoot.settingsRoot.keyremapDetailOpen
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        title: "Keyboards"
        subtitle: KeyboardRemap.availableDevices.length > 0 ? "Connected and saved keyboard profiles" : "No keyboards detected"

        Repeater {
            model: KeyboardRemap.availableDevices
            delegate: SettingsRow {
                required property var modelData
                readonly property int presetCount: KeyboardRemap.devicePresetCount(modelData.hyprName)
                iconName: "keyboard"
                label: modelData.displayName
                description: modelData.connected
                    ? (modelData.keydId || "missing keyd id")
                    : `${modelData.keydId || "missing keyd id"} · saved, disconnected`
                value: presetCount > 0 ? `${presetCount} preset${presetCount === 1 ? "" : "s"}` : "no presets"
                valueColor: presetCount > 0 ? SettingsTokens.accent : SettingsTokens.muted
                rightInset: 30
                showChevron: true
                onClicked: {
                    KeyboardRemap.selectDevice(modelData.hyprName);
                    keyremapRoot.settingsRoot.keyremapDetailOpen = true;
                }

                // Green dot — connected indicator
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: modelData.connected ? "#4ade80" : SettingsTokens.muted
                    border.width: 1
                    border.color: modelData.connected ? "#22c55e" : SettingsTokens.line
                }
            }
        }

        SettingsRow {
            visible: KeyboardRemap.availableDevices.length === 0
            iconName: "info"
            label: "No keyboards found"
            description: "Refresh after connecting a keyboard."
        }
    }

    // ══ DETAIL VIEW: Per-keyboard preset configuration ══

    // ── Device header + enable toggle ──

    SettingsCard {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        title: KeyboardRemap.selectedDeviceId !== "" ? (KeyboardRemap.selectedProfile?.displayName ?? KeyboardRemap.selectedDeviceId) : "Keyboard"
        subtitle: {
            if (KeyboardRemap.selectedDeviceId === "")
                return ""
            const n = KeyboardRemap.devicePresetCount(KeyboardRemap.selectedDeviceId)
            return n > 0 ? `${n} preset${n === 1 ? "" : "s"} active` : "No presets active"
        }
        visible: keyremapRoot.settingsRoot.keyremapDetailOpen && KeyboardRemap.selectedDeviceId !== ""

        ButtonRow {
            SettingsButton {
                label: "Back to keyboards"
                iconName: "chevron_left"
                onClicked: keyremapRoot.settingsRoot.keyremapDetailOpen = false
            }
            SettingsButton {
                visible: KeyboardRemap.selectedDevice?.connected === false
                label: "Remove saved profile"
                iconName: "delete"
                onClicked: {
                    KeyboardRemap.deleteProfile(KeyboardRemap.selectedDeviceId)
                    keyremapRoot.settingsRoot.keyremapDetailOpen = false
                }
            }
        }

        SettingsRow {
            iconName: "badge"
            label: KeyboardRemap.selectedDevice?.keydId || "Missing keyd id"
            description: KeyboardRemap.selectedKeydIdMissing ? "Remaps cannot apply until this ID is resolved." : "keyd vendor:product id"
            value: KeyboardRemap.selectedEnabled ? "Enabled" : "Disabled"
            valueColor: KeyboardRemap.selectedEnabled ? SettingsTokens.accent : SettingsTokens.muted
        }

        SettingsToggleRow {
            iconName: "power_settings_new"
            label: "Enable this keyboard"
            description: "When off, no presets are emitted for this keyboard."
            checked: KeyboardRemap.selectedEnabled
            onToggled: KeyboardRemap.setProfileEnabled(!KeyboardRemap.selectedEnabled)
        }
    }

    // ── Preset toggles for this keyboard ──

    SettingsCard {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        title: "Presets"
        subtitle: {
            const n = KeyboardRemap.devicePresetCount(KeyboardRemap.selectedDeviceId)
            return n > 0 ? `${n} enabled` : "Toggle presets for this keyboard"
        }
        visible: keyremapRoot.settingsRoot.keyremapDetailOpen && KeyboardRemap.selectedDeviceId !== ""

        Repeater {
            model: KeyboardRemap.globalPresetChoices
            delegate: SettingsRow {
                required property var modelData
                readonly property bool isRemap: modelData.type === "remap"
                readonly property string overrideKey: KeyboardRemap.presetOverride(KeyboardRemap.selectedDeviceId, modelData.id)
                readonly property string effectiveTarget: overrideKey.length > 0 ? overrideKey : (modelData.remaps?.[0]?.to ?? "")
                iconName: "tune"
                label: modelData.label
                description: overrideKey.length > 0
                    ? `${modelData.remaps[0].from} → ${overrideKey} (custom)`
                    : modelData.description
                value: ""
                rightInset: isRemap ? 110 : 70
                showChevron: false
                onClicked: KeyboardRemap.setDevicePresetEnabled(KeyboardRemap.selectedDeviceId, modelData.id, !KeyboardRemap.devicePresetEnabled(KeyboardRemap.selectedDeviceId, modelData.id))

                // Edit button — only for remap-type presets
                Rectangle {
                    visible: isRemap
                    anchors.right: toggleSwitch.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    radius: SettingsTokens.radius
                    color: editMouse.containsMouse ? SettingsTokens.buttonHover : "transparent"

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "edit"
                        iconSize: 16
                        color: overrideKey.length > 0 ? SettingsTokens.accent : SettingsTokens.muted
                    }

                    MouseArea {
                        id: editMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: keyremapRoot.settingsRoot.keyremapEditingPreset = modelData.id
                    }
                }

                // Toggle switch
                Rectangle {
                    id: toggleSwitch
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 46
                    height: 26
                    radius: height / 2
                    color: KeyboardRemap.devicePresetEnabled(KeyboardRemap.selectedDeviceId, modelData.id) ? SettingsTokens.accent : SettingsTokens.line

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        anchors.verticalCenter: parent.verticalCenter
                        x: KeyboardRemap.devicePresetEnabled(KeyboardRemap.selectedDeviceId, modelData.id) ? parent.width - width - 3 : 3
                        color: KeyboardRemap.devicePresetEnabled(KeyboardRemap.selectedDeviceId, modelData.id) ? "#111111" : "#dedede"
                        Behavior on x { NumberAnimation { duration: 110 } }
                    }
                }
            }
        }
    }
}
