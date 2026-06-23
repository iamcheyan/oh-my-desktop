import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool showHoverPopup: true
    implicitWidth: rowLayout.implicitWidth
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
        anchors.centerIn: parent
        spacing: 4

        StyledText {
            font.pixelSize: 12
            font.variableAxes: ({
                "wght": 500,
                "wdth": 100,
            })
            color: Appearance.colors.colBarText
            text: root.displayText
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: root.showHoverPopup && !Config.options.bar.tooltips.clickToShow

        ClockWidgetPopup {
            hoverTarget: root.showHoverPopup ? mouseArea : null
        }
    }
}
