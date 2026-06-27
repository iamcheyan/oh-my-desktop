import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool showHoverPopup: true
    readonly property color tuiBg: "#030806"
    readonly property color tuiFg: "#e8fff3"
    readonly property color tuiDim: "#65736e"
    readonly property color tuiLine: "#174339"
    readonly property color tuiGreen: "#36ff8b"
    readonly property color tuiBlue: "#7bc7ff"
    implicitWidth: clockFrame.implicitWidth
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

    RowLayout {
        id: rowLayout
        visible: false
    }

    Rectangle {
        id: clockFrame
        anchors.centerIn: parent
        implicitWidth: clockRow.implicitWidth + 18
        implicitHeight: 26
        color: root.tuiBg
        border.width: 1
        border.color: mouseArea.containsMouse || GlobalStates.scheduleOpen ? root.tuiGreen : root.tuiLine
        radius: 0

        RowLayout {
            id: clockRow
            anchors.centerIn: parent
            spacing: 8

            StyledText {
                text: "TIME"
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Bold
                color: root.tuiGreen
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 13
                color: root.tuiLine
            }

            StyledText {
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Bold
                color: root.tuiFg
                text: root.displayText
            }
        }
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
