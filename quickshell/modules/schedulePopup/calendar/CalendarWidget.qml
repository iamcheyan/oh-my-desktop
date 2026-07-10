import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import "calendar_layout.js" as CalendarLayout
import QtQuick
import QtQuick.Layouts

Item {
    readonly property var englishLocale: Qt.locale("en_US")
    readonly property var today: new Date()
    property bool showTodayHero: false
    property bool hubMode: false
    property int monthShift: 0
    property real wheelAccum: 0
    property var viewingDate: CalendarLayout.getDateInXMonthsTime(monthShift)
    property var calendarLayout: CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0)
    readonly property int cellSize: hubMode ? 32 : 38
    readonly property int cellSpacing: hubMode ? 4 : 5

    width: calendarColumn.width
    implicitHeight: calendarColumn.implicitHeight

    Keys.onPressed: event => {
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp)
            && event.modifiers === Qt.NoModifier) {
            monthShift += event.key === Qt.Key_PageDown ? 1 : -1;
            event.accepted = true;
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: event => {
            const r = WheelUtils.getSteps(event.angleDelta.y, wheelAccum);
            wheelAccum = r.accum;
            monthShift -= r.steps;
        }
    }

    ColumnLayout {
        id: calendarColumn
        width: parent.width
        spacing: hubMode ? 10 : 5

        ColumnLayout {
            Layout.fillWidth: true
            visible: showTodayHero
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: today.toLocaleDateString(englishLocale, "dddd")
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: TuiStyle.dim
            }

            StyledText {
                Layout.fillWidth: true
                text: today.toLocaleDateString(englishLocale, "d MMMM yyyy")
                font.family: Appearance.font.family.main
                font.pixelSize: hubMode ? Appearance.font.pixelSize.large : Appearance.font.pixelSize.larger
                font.weight: Font.DemiBold
                color: TuiStyle.fg
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: cellSpacing

            NavButton {
                symbol: "chevron_left"
                onClicked: { monthShift--; }
            }

            CalendarHeaderButton {
                Layout.fillWidth: true
                clip: true
                buttonText: `${monthShift !== 0 ? "• " : ""}${viewingDate.toLocaleDateString(englishLocale, "MMMM yyyy")}`
                tooltipText: monthShift === 0 ? "" : "Jump to current month"
                downAction: () => {
                    monthShift = 0;
                }
            }

            NavButton {
                symbol: "chevron_right"
                onClicked: { monthShift++; }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: cellSpacing
            Repeater {
                model: CalendarLayout.weekDays
                delegate: CalendarDayButton {
                    day: modelData.day
                    isToday: modelData.today
                    bold: true
                    compact: hubMode
                    enabled: false
                }
            }
        }

        Repeater {
            model: 6
            delegate: RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: cellSpacing
                Repeater {
                    model: Array(7).fill(modelData)
                    delegate: CalendarDayButton {
                        day: calendarLayout[modelData][index].day
                        isToday: calendarLayout[modelData][index].today
                        compact: hubMode
                    }
                }
            }
        }
    }

    component NavButton: Item {
        id: navButton
        property string symbol: ""

        signal clicked()

        Layout.preferredWidth: 32
        Layout.preferredHeight: 32

        RippleButton {
            anchors.fill: parent
            buttonRadius: Appearance.rounding.full
            colBackground: TuiStyle.surfaceSubtle
            colBackgroundHover: TuiStyle.surfaceHover
            colRipple: TuiStyle.line
            downAction: () => navButton.clicked()

            MaterialSymbol {
                anchors.centerIn: parent
                text: navButton.symbol
                iconSize: 18
                color: TuiStyle.fg
            }
        }
    }
}