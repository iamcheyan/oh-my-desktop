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

    readonly property color tuiBg: TuiStyle.bg
    readonly property color tuiPanel: TuiStyle.panel
    readonly property color tuiPanelAlt: TuiStyle.panelAlt
    readonly property color tuiFg: TuiStyle.fg
    readonly property color tuiDim: TuiStyle.dim
    readonly property color tuiLine: TuiStyle.line
    readonly property color tuiAccent: TuiStyle.accent
    readonly property color tuiYellow: TuiStyle.yellow
    readonly property color tuiBlue: TuiStyle.blue
    readonly property color tuiPurple: TuiStyle.purple
    readonly property color tuiRed: TuiStyle.red

    function sortedNotifications() {
        return Notifications.list.slice().sort((a, b) => b.time - a.time);
    }

    ListView {
        id: listView
        anchors.fill: parent
        clip: true
        spacing: 0
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
        color: "#202020"
        radius: TuiStyle.radius
        border.width: 0

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "NO NOTIFICATIONS"
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.DemiBold
                color: root.tuiFg
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "queue is clean"
                font.family: Appearance.font.family.main
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

        color: rowTap.pressed ? "#303030"
            : rowHover.hovered || expanded ? "#242424"
            : "transparent"
        border.width: 0
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
            width: critical ? 2 : 0
            color: critical ? root.tuiRed : root.tuiAccent
        }

        ColumnLayout {
            id: rowContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: critical ? 14 : 12
            anchors.rightMargin: 8
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                StyledText {
                    text: String(rowIndex + 1).padStart(2, "0")
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: root.tuiDim
                }

                StyledText {
                    Layout.preferredWidth: 120
                    text: notificationObject?.appName || "notification"
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: critical ? root.tuiFg : root.tuiDim
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: notificationObject?.summary || ""
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
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
                    font.weight: Font.Medium
                    color: root.tuiDim
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
                font.family: Appearance.font.family.main
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

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: root.tuiLine
            opacity: 0.22
        }

    }

    component MiniButton: Rectangle {
        id: button

        property string label: ""
        property color accent: root.tuiAccent
        signal clicked()

        Layout.preferredHeight: 22
        Layout.preferredWidth: Math.max(24, labelText.implicitWidth + 12)
        radius: 4
        color: buttonMouse.pressed ? "#3a3a3a"
            : buttonMouse.containsMouse ? "#303030"
            : "transparent"
        border.width: 0

        StyledText {
            id: labelText
            anchors.centerIn: parent
            text: button.label
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: buttonMouse.containsMouse ? root.tuiFg : root.tuiDim
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
