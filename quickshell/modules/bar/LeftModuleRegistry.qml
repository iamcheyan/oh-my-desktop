pragma ComponentBehavior: Bound

import QtQuick
import qs

QtObject {
    id: registry

    component ModuleEntry: QtObject {
        property string name
        property Component component
        property string description
    }

    readonly property var entries: ({
        "appLauncher": { component: Qt.createComponent("AppLauncherButton.qml"), description: qsTr("App launcher toggle button") },
        "workspaces": { component: Qt.createComponent("Workspaces.qml"), description: qsTr("Workspaces button") },
        "activeWindow": { component: Qt.createComponent("ActiveWindow.qml"), description: qsTr("Active window icon and title") },
        "clock": { component: Qt.createComponent("ClockWidget.qml"), description: qsTr("Clock (click to open schedule)") },
        "media": { component: Qt.createComponent("Media.qml"), description: qsTr("Media controls") },
        "spacer": { component: Qt.createComponent("SpacerItem.qml"), description: qsTr("Flexible spacer") }
    })

    function componentForName(name) {
        const entry = registry.entries[name];
        return entry ? entry.component : null;
    }

    function descriptionForName(name) {
        const entry = registry.entries[name];
        return entry ? entry.description : name;
    }

    function allNames() {
        return Object.keys(registry.entries);
    }
}