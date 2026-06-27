import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool showHoverPopup: true
    implicitWidth: clockText.implicitWidth + 16
    implicitHeight: Appearance.sizes.barHeight

    readonly property var weekdays: ["日", "月", "火", "水", "木", "金", "土"]

    function formatDateTime() {
        var d = new Date();
        var month = d.getMonth() + 1;
        var day = d.getDate();
        var wd = root.weekdays[d.getDay()];
        var h = d.getHours().toString().padStart(2, "0");
        var m = d.getMinutes().toString().padStart(2, "0");
        return month + "月" + day + "日(" + wd + ") " + h + ":" + m;
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
        font.family: Appearance.font.family.monospace
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.Bold
        color: Appearance.colors.colBarText
        text: root.displayText
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: root.showHoverPopup && !Config.options.bar.tooltips.clickToShow
        cursorShape: Qt.PointingHandCursor
        onClicked: GlobalStates.scheduleOpen = !GlobalStates.scheduleOpen

        ClockWidgetPopup {
            hoverTarget: root.showHoverPopup ? mouseArea : null
        }
    }
}
