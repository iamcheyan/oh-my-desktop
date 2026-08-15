// ToolLauncherRow — row icon + title + subtitle for the tools popup.
pragma ComponentBehavior: Bound
import qs.modules.common.widgets
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
