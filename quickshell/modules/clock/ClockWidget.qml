import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    implicitWidth: clockText.implicitWidth + 16
    implicitHeight: Appearance.sizes.barHeight
    property string moduleId: "clock"

    readonly property var weekdays: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    readonly property var months: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    function formatDateTime(date) {
        var d = date;
        var monthStr = root.months[d.getMonth()];
        var day = d.getDate();
        var wd = root.weekdays[d.getDay()];
        var h = d.getHours().toString().padStart(2, "0");
        var m = d.getMinutes().toString().padStart(2, "0");
        return wd + " " + monthStr + " " + day + " " + h + ":" + m;
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Rectangle {
        id: hoverBg
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        radius: height / 2
        color: (mouseArea.containsMouse || GlobalStates.barPopupType === "notifications") ? (GlobalStates.barPopupType === "notifications" ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.10)) : "transparent"

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    StyledText {
        id: clockText
        anchors.centerIn: parent
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.Normal
        color: Appearance.colors.colBarText
        text: root.formatDateTime(clock.date)
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (Date.now() - GlobalStates.barPopupDismissedAt < 200) return;
            GlobalStates.barPopupType = GlobalStates.barPopupType === "notifications" ? "" : "notifications"
        }
    }

    Component {
        id: hoverComponent
        HoverInfo {}
    }

    Component.onCompleted: HoverInfoService.register(root.moduleId, hoverComponent)
    Component.onDestruction: HoverInfoService.unregister(root.moduleId)

    HoverInfoPopup {
        moduleId: root.moduleId
        hoverTarget: mouseArea
    }
}
