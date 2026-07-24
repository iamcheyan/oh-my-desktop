pragma ComponentBehavior: Bound

import qs.modules.common.widgets
import qs.core.runtime
import QtQuick
import Quickshell

StyledListView { // Scrollable window
    id: root
    property bool popup: false

    spacing: 4

    model: ScriptModel {
        values: root.popup ? ServiceManager.notification.popupAppNameList : ServiceManager.notification.appNameList
    }
    delegate: NotificationGroup {
        required property int index
        required property var modelData
        popup: root.popup
        width: ListView.view.width // https://doc.qt.io/qt-6/qml-qtquick-listview.html
        notificationGroup: popup ? 
            ServiceManager.notification.popupGroupsByAppName[modelData] :
            ServiceManager.notification.groupsByAppName[modelData]
    }
}
