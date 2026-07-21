// ModulesPage — Module management settings page.
// Shows installed modules with enable/disable toggles.
// Respects modules.enabled master switch from sumika.json.

import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import qs.modules.settings.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

PageBody {
    id: page
    settingsRoot: parent?.settingsRoot ?? root

    readonly property var modules: ModuleLoader._registry.modules ?? []

    // Master switch from config
    readonly property bool masterEnabled: Config.options.modules?.enabled !== false

    function setMasterEnabled(enabled) {
        Config.setNestedValue("modules.enabled", enabled)
    }



    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        PopupHeader {
            Layout.fillWidth: true
            icon: NerdIconMap.extension
            title: "Modules"
            subtitle: `${modules.length} installed${masterEnabled ? "" : " · ALL DISABLED"}`
        }

        // Master switch
        SettingsToggleRow {
            Layout.fillWidth: true
            label: "Enable modules"
            description: "Master switch — when off, all modules are disabled"
            checked: page.masterEnabled
            onToggled: page.setMasterEnabled(!page.masterEnabled)
        }

        SettingsSectionDivider {}

        Repeater {
            model: page.modules
            delegate: SettingsRow {
                required property var modelData
                Layout.fillWidth: true

                iconName: "extension"
                label: modelData.name ?? modelData.id ?? "Unknown"
                description: modelData.description ?? modelData.id ?? ""
                showDivider: true

                trailingItem: RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 8

                    StyledText {
                        text: ModuleLoader.isEnabled(modelData.id) ? "ON" : "OFF"
                        color: ModuleLoader.isEnabled(modelData.id) ? TuiStyle.accent : TuiStyle.dim
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                    }

                    RippleButton {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        Layout.alignment: Qt.AlignVCenter
                        buttonRadius: 18
                        colBackground: "transparent"
                        colBackgroundHover: Qt.rgba(1, 1, 1, 0.10)
                        colRipple: Qt.rgba(1, 1, 1, 0.12)
                        toggled: ModuleLoader.isEnabled(modelData.id)

                        onClicked: page.setMasterEnabled(!page.masterEnabled)

                        BarNerdIcon {
                            anchors.centerIn: parent
                            text: ModuleLoader.isEnabled(modelData.id) ? NerdIconMap.check : NerdIconMap.close
                            iconSize: 16
                            color: ModuleLoader.isEnabled(modelData.id) ? TuiStyle.accent : TuiStyle.dim
                        }
                    }
                }
            }
        }

        // Info footer
        SettingsSection {
            Layout.fillWidth: true
            Layout.topMargin: 16

            StyledText {
                Layout.fillWidth: true
                text: "Changes apply after restart (omd-restart)"
                color: TuiStyle.dim
                font.pixelSize: Appearance.font.pixelSize.small
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}