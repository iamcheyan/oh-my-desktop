import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    readonly property color tuiBg: "#030806"
    readonly property color tuiPanel: "#06110e"
    readonly property color tuiFg: "#e8fff3"
    readonly property color tuiDim: "#65736e"
    readonly property color tuiLine: "#174339"
    readonly property color tuiGreen: "#36ff8b"
    readonly property color tuiBlue: "#7bc7ff"
    readonly property color tuiPurple: "#c792ea"

    property string formattedDate: Qt.locale().toString(DateTime.clock.date, "dddd, MMMM dd, yyyy")
    property string formattedTime: DateTime.time
    property string formattedUptime: DateTime.uptime
    property string todosSection: getUpcomingTodos()

    function getUpcomingTodos() {
        const unfinishedTodos = Todo.list.filter(function (item) {
            return !item.done;
        });
        if (unfinishedTodos.length === 0)
            return Translation.tr("No pending tasks");

        const limitedTodos = unfinishedTodos.slice(0, 4);
        let todoText = limitedTodos.map(function (item, index) {
            return `${index + 1}. ${item.content}`;
        }).join("\n");

        if (unfinishedTodos.length > 4)
            todoText += `\n+${unfinishedTodos.length - 4} more`;

        return todoText;
    }

    Rectangle {
        implicitWidth: 300
        implicitHeight: popupColumn.implicitHeight + 24
        color: root.tuiBg
        border.width: 1
        border.color: root.tuiLine
        radius: 0

        ColumnLayout {
            id: popupColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                color: root.tuiPanel
                border.width: 1
                border.color: root.tuiGreen

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    StyledText {
                        text: "CLOCK"
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Bold
                        color: root.tuiGreen
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root.tuiLine
                    }

                    StyledText {
                        text: root.formattedTime
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Bold
                        color: root.tuiFg
                    }
                }
            }

            DetailRow {
                keyText: "DATE"
                valueText: root.formattedDate
                valueColor: root.tuiBlue
            }

            DetailRow {
                keyText: "UPTIME"
                valueText: root.formattedUptime
                valueColor: root.tuiPurple
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.tuiLine
            }

            StyledText {
                Layout.fillWidth: true
                text: "TODO"
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Bold
                color: root.tuiDim
            }

            StyledText {
                Layout.fillWidth: true
                text: root.todosSection
                wrapMode: Text.Wrap
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.tuiFg
            }
        }
    }

    component DetailRow: RowLayout {
        property string keyText: ""
        property string valueText: ""
        property color valueColor: root.tuiFg

        Layout.fillWidth: true
        spacing: 10

        StyledText {
            Layout.preferredWidth: 62
            text: keyText
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.Bold
            color: root.tuiDim
        }

        StyledText {
            Layout.fillWidth: true
            text: valueText
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.Bold
            color: valueColor
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }
}
