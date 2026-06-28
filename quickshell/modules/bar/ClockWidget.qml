import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    implicitWidth: clockText.implicitWidth + 16
    implicitHeight: Appearance.sizes.barHeight

    readonly property var weekdays: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    readonly property var months: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    function formatDateTime() {
        var d = new Date();
        var monthStr = root.months[d.getMonth()];
        var day = d.getDate();
        var wd = root.weekdays[d.getDay()];
        var h = d.getHours().toString().padStart(2, "0");
        var m = d.getMinutes().toString().padStart(2, "0");
        return wd + " " + monthStr + " " + day + " " + h + ":" + m;
    }

    property string displayText: formatDateTime()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.displayText = root.formatDateTime()
    }

    StyledText {
        id: clockText
        anchors.centerIn: parent
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.Normal
        color: Appearance.colors.colBarText
        text: root.displayText
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: GlobalStates.barPopupType = GlobalStates.barPopupType === "schedule" ? "" : "schedule"
    }

    ClockHoverPopup {
        id: clockHoverPopup
        hoverTarget: mouseArea
    }
}
