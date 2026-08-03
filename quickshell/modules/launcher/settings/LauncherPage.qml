import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.settings
import qs.modules.settings.widgets
import QtQuick
import QtQuick.Layouts

PageBody {
    id: page
    property var settingsRoot: null

    SettingsSection {
        title: "性能"

        SettingsToggleRow {
            label: "启动器常驻内存"
            description: "保持启动器进程常驻，打开时即时响应，不再冷启动。下次会话启动时生效。"
            checked: Config.options.launcher.resident
            onToggled: Config.setNestedValue("launcher.resident", !Config.options.launcher.resident)
        }
    }
}