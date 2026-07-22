// ToolLauncherRow — row icon + title + subtitle for the tools popup.
import qs.modules.settings.widgets
import QtQuick

SettingsNavigationRow {
    id: toolRow

    property string icon: ""
    property string title: ""
    property string subtitle: ""

    iconName: icon
    label: title
    description: subtitle
}
