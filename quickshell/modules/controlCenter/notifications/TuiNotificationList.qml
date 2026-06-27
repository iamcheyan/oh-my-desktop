import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: root

    implicitHeight: Notifications.list.length === 0 ? 96 : listView.contentHeight

    readonly property color tuiBg: "#030806"
    readonly property color tuiPanel: "#06110e"
    readonly property color tuiPanelAlt: "#091814"
    readonly property color tuiFg: "#e8fff3"
    readonly property color tuiDim: "#65736e"
    readonly property color tuiLine: "#174339"
    readonly property color tuiGreen: "#36ff8b"
    readonly property color tuiYellow: "#e8ff82"
    readonly property color tuiBlue: "#7bc7ff"
    readonly property color tuiPurple: "#c792ea"
    readonly property color tuiRed: "#ff6b8b"

    function sortedNotifications() {
        return Notifications.list.slice().sort((a, b) => b.time - a.time);
    }

    ListView {
        id: listView
        anchors.fill: parent
        clip: true
        spacing: 6
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel {
            values: root.sortedNotifications()
        }

        delegate: NotificationRow {
            required property int index
            required property var modelData
            width: ListView.view.width
            notificationObject: modelData
            rowIndex: index
        }
    }

    Rectangle {
        anchors.centerIn: parent
        visible: Notifications.list.length === 0
        width: Math.min(parent.width - 24, 360)
        height: 96
        color: root.tuiPanelAlt
        border.width: 1
        border.color: root.tuiLine

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "NO NOTIFICATIONS"
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.Bold
                color: root.tuiGreen
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "queue is clean"
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
                color: root.tuiDim
            }
        }
    }

    component NotificationRow: Rectangle {
        id: row

        required property var notificationObject
        required property int rowIndex
        readonly property bool critical: notificationObject?.urgency == NotificationUrgency.Critical
            || notificationObject?.urgency == NotificationUrgency.Critical.toString()
        readonly property bool expanded: expandedRows[notificationObject?.notificationId] ?? false
        property var expandedRows: ({})

        function bodyText() {
            return NotificationUtils.processNotificationBody(
                notificationObject?.body || "",
                notificationObject?.appName || notificationObject?.summary || ""
            );
        }

        function setExpanded(value) {
            const next = Object.assign({}, expandedRows);
            next[notificationObject.notificationId] = value;
            expandedRows = next;
        }

        function toggleExpanded() {
            setExpanded(!expanded);
        }

        function discard() {
            Notifications.discardNotification(notificationObject.notificationId);
        }

        color: rowTap.pressed ? root.tuiPanelAlt
            : rowHover.hovered || expanded ? Qt.rgba(root.tuiGreen.r, root.tuiGreen.g, root.tuiGreen.b, 0.08)
            : root.tuiBg
        border.width: 1
        border.color: critical ? root.tuiRed : rowHover.hovered || expanded ? root.tuiGreen : root.tuiLine
        implicitHeight: rowContent.implicitHeight + 18

        HoverHandler {
            id: rowHover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: rowTap
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onTapped: (eventPoint, button) => {
                if (button === Qt.MiddleButton)
                    row.discard();
                else
                    row.toggleExpanded();
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3
            color: critical ? root.tuiRed : root.tuiGreen
        }

        ColumnLayout {
            id: rowContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 14
            anchors.rightMargin: 10
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                StyledText {
                    text: String(rowIndex + 1).padStart(2, "0")
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Bold
                    color: root.tuiDim
                }

                StyledText {
                    Layout.preferredWidth: 130
                    text: notificationObject?.appName || "notification"
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Bold
                    color: critical ? root.tuiRed : root.tuiBlue
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: notificationObject?.summary || ""
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Bold
                    color: root.tuiFg
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    textFormat: Text.PlainText
                }

                StyledText {
                    visible: notificationObject?.actions?.length > 0
                    text: `A${notificationObject?.actions?.length ?? 0}`
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Bold
                    color: root.tuiPurple
                }

                StyledText {
                    text: NotificationUtils.getFriendlyNotifTimeString(notificationObject?.time)
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.tuiDim
                }

                MiniButton {
                    label: expanded ? "-" : "+"
                    accent: root.tuiYellow
                    onClicked: row.toggleExpanded()
                }

                MiniButton {
                    label: "x"
                    accent: root.tuiRed
                    onClicked: row.discard()
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: (notificationObject?.body || "").length > 0
                text: row.bodyText().replace(/\n/g, expanded ? "<br/>" : " ")
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
                color: root.tuiDim
                elide: Text.ElideRight
                maximumLineCount: expanded ? 6 : 1
                wrapMode: expanded ? Text.Wrap : Text.NoWrap
                textFormat: expanded ? Text.RichText : Text.StyledText
                onLinkActivated: link => {
                    Qt.openUrlExternally(link);
                    GlobalStates.controlCenterOpen = false;
                }
                PointingHandLinkHover {}
            }

            RowLayout {
                Layout.fillWidth: true
                visible: expanded
                spacing: 6

                MiniButton {
                    label: "close"
                    accent: root.tuiRed
                    onClicked: row.discard()
                }

                MiniButton {
                    id: copyButton
                    label: "copy"
                    accent: root.tuiBlue
                    onClicked: {
                        Quickshell.clipboardText = notificationObject?.body || notificationObject?.summary || "";
                        copyButton.label = "copied";
                        copyTimer.restart();
                    }

                    Timer {
                        id: copyTimer
                        interval: 1500
                        repeat: false
                        onTriggered: copyButton.label = "copy"
                    }
                }

                Repeater {
                    model: notificationObject?.actions ?? []
                    MiniButton {
                        required property var modelData
                        label: modelData.text
                        accent: root.tuiPurple
                        onClicked: Notifications.attemptInvokeAction(notificationObject.notificationId, modelData.identifier)
                    }
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }

    }

    component MiniButton: Rectangle {
        id: button

        property string label: ""
        property color accent: root.tuiGreen
        signal clicked()

        Layout.preferredHeight: 22
        Layout.preferredWidth: Math.max(24, labelText.implicitWidth + 12)
        color: buttonMouse.pressed ? Qt.rgba(button.accent.r, button.accent.g, button.accent.b, 0.22)
            : buttonMouse.containsMouse ? Qt.rgba(button.accent.r, button.accent.g, button.accent.b, 0.12)
            : "transparent"
        border.width: 1
        border.color: buttonMouse.containsMouse ? button.accent : root.tuiLine

        StyledText {
            id: labelText
            anchors.centerIn: parent
            text: button.label
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.Bold
            color: button.accent
            elide: Text.ElideRight
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                mouse.accepted = true;
                button.clicked();
            }
        }
    }
}
