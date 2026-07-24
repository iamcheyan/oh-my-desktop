// ModulesPage — Module management settings page.
// Shows installed modules with enable/disable toggles.
// Product-floor modules always stay on; master switch only affects optional modules.

import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import qs.modules.settings.widgets
import qs.core.runtime
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

PageBody {
    id: page
    settingsRoot: parent?.settingsRoot ?? root

    readonly property var modules: ModuleLoader.modules ?? []

    // Master switch from config (optional modules only)
    readonly property bool masterEnabled: Config.options.modules?.enabled !== false

    // Current module exclusion list
    property var _disabledList: []

    function syncDisabledList() {
        const raw = Config.options.modules?.disabled
        page._disabledList = Array.isArray(raw) ? raw.slice() : []
    }

    function setMasterEnabled(enabled) {
        Config.setNestedValue("modules.enabled", enabled)
    }

    function toggleModule(moduleId) {
        if (ModuleLoader.isRequired(moduleId))
            return
        page.syncDisabledList()
        const idx = page._disabledList.indexOf(moduleId)
        if (idx >= 0) {
            // Re-enable: remove from exclusion list
            page._disabledList.splice(idx, 1)
        } else {
            // Disable: add to exclusion list
            page._disabledList.push(moduleId)
        }
        Config.setNestedValue("modules.disabled", page._disabledList)
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        PopupHeader {
            Layout.fillWidth: true
            icon: NerdIconMap.extension
            title: "Modules"
            subtitle: {
                const total = page.modules.length
                const active = page.modules.filter(m => ModuleLoader.isEnabled(m.id)).length
                if (!page.masterEnabled)
                    return `Minimum desktop (${active}/${total} active)`
                return `${active}/${total} active`
            }
        }

        // Master switch
        SettingsToggleRow {
            Layout.fillWidth: true
            label: "Enable optional modules"
            description: "When off, only the minimum desktop remains: launcher, clock, notification-popup, workspaces, overview, systray, Wi‑Fi, audio, power"
            checked: page.masterEnabled
            onToggled: page.setMasterEnabled(!page.masterEnabled)
        }

        SettingsSectionDivider {}

        Repeater {
            model: page.modules
            delegate: SettingsRow {
                required property var modelData
                Layout.fillWidth: true

                readonly property bool requiredModule: ModuleLoader.isRequired(modelData.id)
                readonly property bool moduleOn: ModuleLoader.isEnabled(modelData.id)

                iconName: requiredModule ? "lock" : "extension"
                label: {
                    const name = modelData.name ?? modelData.id ?? "Unknown"
                    return requiredModule ? `${name} (required)` : name
                }
                description: {
                    if (requiredModule)
                        return "Minimum desktop — cannot be disabled"
                    return modelData.description ?? modelData.id ?? ""
                }
                showDivider: true

                trailingItem: RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 8

                    StyledText {
                        text: requiredModule ? "REQ" : (moduleOn ? "ON" : "OFF")
                        color: requiredModule ? TuiStyle.accent : (moduleOn ? TuiStyle.accent : TuiStyle.dim)
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                    }

                    RippleButton {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        Layout.alignment: Qt.AlignVCenter
                        buttonRadius: 18
                        enabled: !requiredModule && page.masterEnabled
                        opacity: enabled ? 1.0 : 0.45
                        colBackground: "transparent"
                        colBackgroundHover: Qt.rgba(1, 1, 1, 0.10)
                        colRipple: Qt.rgba(1, 1, 1, 0.12)
                        toggled: moduleOn

                        onClicked: page.toggleModule(modelData.id)

                        BarNerdIcon {
                            anchors.centerIn: parent
                            text: requiredModule ? NerdIconMap.lock : (moduleOn ? NerdIconMap.check : NerdIconMap.close)
                            iconSize: 16
                            color: requiredModule ? TuiStyle.accent : (moduleOn ? TuiStyle.accent : TuiStyle.dim)
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
                text: "Minimum desktop: launcher, clock, workspaces, systray, Wi‑Fi, audio, power. Changes apply after reload."
                color: TuiStyle.dim
                font.pixelSize: Appearance.font.pixelSize.small
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
}
