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

    property bool showHeader: false
    property bool markReadOnVisible: false
    property int maxListHeight: 360
    property var expandedRows: ({})

    readonly property int headerGap: showHeader ? 10 : 0
    readonly property int listHeight: Math.max(112, Math.min(maxListHeight, listView.contentHeight))

    implicitHeight: (showHeader ? header.implicitHeight : 0) + headerGap + listHeight

    onVisibleChanged: {
        if (visible && markReadOnVisible)
            Notifications.markAllRead();
    }

    function sortedNotifications() {
        return Notifications.list.slice().sort((a, b) => b.time - a.time);
    }

    function isExpanded(notificationId) {
        return expandedRows[notificationId] ?? false;
    }

    function setExpanded(notificationId, value) {
        const next = Object.assign({}, expandedRows);
        next[notificationId] = value;
        expandedRows = next;
    }

    function toggleExpanded(notificationId) {
        setExpanded(notificationId, !isExpanded(notificationId));
    }

    Rectangle {
        id: header
        visible: root.showHeader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        implicitHeight: visible ? 38 : 0
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    text: "Notifications"
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: TuiStyle.fg
                }

                StyledText {
                    text: Notifications.silent
                        ? "Do not disturb is on"
                        : (Notifications.list.length === 0
                            ? "All clear"
                            : `${Notifications.list.length} item${Notifications.list.length === 1 ? "" : "s"}`)
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: TuiStyle.dim
                }
            }

            PillButton {
                label: Notifications.silent ? "DND" : "Live"
                active: !Notifications.silent
                accent: Notifications.silent ? TuiStyle.warning : TuiStyle.success
                onClicked: Notifications.silent = !Notifications.silent
            }

            IconButton {
                symbol: "done_all"
                tooltip: "Mark read"
                enabled: Notifications.unread > 0
                onClicked: Notifications.markAllRead()
            }

            IconButton {
                symbol: "delete_sweep"
                tooltip: "Clear all"
                enabled: Notifications.list.length > 0
                danger: true
                onClicked: Notifications.discardAllNotifications()
            }
        }
    }

    ListView {
        id: listView
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: root.showHeader ? header.bottom : parent.top
        anchors.topMargin: root.headerGap
        height: root.listHeight
        clip: true
        spacing: 8
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

    Item {
        anchors.fill: listView
        visible: Notifications.list.length === 0

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 24, 280)
            spacing: 10

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                radius: 21
                color: TuiStyle.surfaceHover
                border.width: 0

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: Notifications.silent ? "notifications_paused" : "notifications"
                    iconSize: 22
                    color: Notifications.silent ? TuiStyle.warning : TuiStyle.accent
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Notifications.silent ? "Notifications paused" : "Nothing new"
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: TuiStyle.fg
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Notifications.silent ? "Incoming popups stay quiet." : "New messages will appear here."
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.small
                color: TuiStyle.dim
                wrapMode: Text.Wrap
            }
        }
    }

    component NotificationRow: Rectangle {
        id: row

        required property var notificationObject
        required property int rowIndex
        readonly property bool critical: notificationObject?.urgency == NotificationUrgency.Critical
            || notificationObject?.urgency == NotificationUrgency.Critical.toString()
        readonly property bool expanded: root.isExpanded(notificationObject?.notificationId)
        readonly property bool hasBody: (notificationObject?.body || "").length > 0
        readonly property bool hasActions: (notificationObject?.actions?.length ?? 0) > 0
        readonly property string displayApp: notificationObject?.appName || "System"

        function bodyText() {
            return NotificationUtils.processNotificationBody(
                notificationObject?.body || "",
                notificationObject?.appName || notificationObject?.summary || ""
            );
        }

        function discard() {
            Notifications.discardNotification(notificationObject.notificationId);
        }

        function copyText() {
            Quickshell.clipboardText = notificationObject?.body || notificationObject?.summary || "";
            copyButton.symbol = "check";
            copyReset.restart();
        }

        // Menu-row chrome (same as BarContextMenuItem): no outline, hover fill only
        implicitHeight: rowContent.implicitHeight + 18
        radius: 5
        color: rowTap.pressed ? TuiStyle.surfacePressed
            : rowHover.hovered || expanded ? TuiStyle.surfaceHover
            : "transparent"
        border.width: 0

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

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
                else if (row.hasBody || row.hasActions)
                    root.toggleExpanded(row.notificationObject.notificationId);
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 6
            anchors.bottomMargin: 6
            width: critical ? TuiStyle.borderWidth : 0
            radius: 1
            color: TuiStyle.danger
        }

        ColumnLayout {
            id: rowContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: critical ? 13 : 10
            anchors.rightMargin: 10
            spacing: 7

            RowLayout {
                Layout.fillWidth: true
                spacing: 9

                Item {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28

                    NotificationAppIcon {
                        anchors.centerIn: parent
                        scale: 28 / 38
                        appIcon: notificationObject?.appIcon || ""
                        image: notificationObject?.image || ""
                        summary: notificationObject?.summary || ""
                        urgency: row.critical ? NotificationUrgency.Critical : NotificationUrgency.Normal
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        StyledText {
                            Layout.fillWidth: true
                            text: notificationObject?.summary || row.displayApp
                            font.family: Appearance.font.family.main
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: TuiStyle.fg
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            textFormat: Text.PlainText
                        }

                        StyledText {
                            text: NotificationUtils.getFriendlyNotifTimeString(notificationObject?.time)
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: TuiStyle.dim
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        StyledText {
                            text: row.displayApp
                            font.family: Appearance.font.family.main
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: TuiStyle.dim
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Rectangle {
                            visible: row.hasActions
                            Layout.preferredWidth: actionCount.implicitWidth + 10
                            Layout.preferredHeight: 18
                            radius: 9
                            color: TuiStyle.surfaceSubtle

                            StyledText {
                                id: actionCount
                                anchors.centerIn: parent
                                text: `${notificationObject?.actions?.length ?? 0} action${(notificationObject?.actions?.length ?? 0) === 1 ? "" : "s"}`
                                font.family: Appearance.font.family.main
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: TuiStyle.dim
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }

                RowLayout {
                    id: rowActions
                    spacing: 4
                    opacity: rowHover.hovered || row.expanded ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: 100 }
                    }

                    IconButton {
                        id: copyButton
                        symbol: "content_copy"
                        tooltip: "Copy"
                        enabled: row.hasBody || (notificationObject?.summary || "").length > 0
                        onClicked: row.copyText()

                        Timer {
                            id: copyReset
                            interval: 1200
                            repeat: false
                            onTriggered: copyButton.symbol = "content_copy"
                        }
                    }

                    IconButton {
                        symbol: row.expanded ? "expand_less" : "expand_more"
                        tooltip: row.expanded ? "Collapse" : "Expand"
                        enabled: row.hasBody || row.hasActions
                        onClicked: root.toggleExpanded(row.notificationObject.notificationId)
                    }

                    IconButton {
                        symbol: "close"
                        tooltip: "Dismiss"
                        danger: true
                        onClicked: row.discard()
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: row.hasBody
                text: row.bodyText().replace(/\n/g, row.expanded ? "<br/>" : " ")
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.small
                color: TuiStyle.dim
                elide: Text.ElideRight
                maximumLineCount: row.expanded ? 7 : 2
                wrapMode: row.expanded ? Text.Wrap : Text.NoWrap
                textFormat: row.expanded ? Text.RichText : Text.StyledText
                onLinkActivated: link => {
                    Qt.openUrlExternally(link);
                    GlobalStates.barPopupType = "";
                }
                PointingHandLinkHover {}
            }

            Flow {
                Layout.fillWidth: true
                visible: row.expanded && row.hasActions
                spacing: 6

                Repeater {
                    model: notificationObject?.actions ?? []
                    PillButton {
                        required property var modelData
                        label: modelData.text
                        active: true
                        accent: TuiStyle.accent
                        onClicked: Notifications.attemptInvokeAction(notificationObject.notificationId, modelData.identifier)
                    }
                }
            }
        }
    }

    component IconButton: Rectangle {
        id: button

        property string symbol: ""
        property string tooltip: ""
        property bool danger: false
        signal clicked()

        implicitWidth: 28
        implicitHeight: 28
        width: implicitWidth
        height: implicitHeight
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        radius: 5
        color: buttonMouse.pressed ? TuiStyle.surfacePressed
            : buttonMouse.containsMouse ? TuiStyle.surfaceHover
            : "transparent"
        opacity: enabled ? 1 : 0.38

        MaterialSymbol {
            anchors.centerIn: parent
            text: button.symbol
            iconSize: 18
            color: button.danger ? TuiStyle.danger : TuiStyle.dim
        }

        StyledToolTip {
            text: button.tooltip
            extraVisibleCondition: button.tooltip.length > 0 && buttonMouse.containsMouse
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            enabled: button.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                mouse.accepted = true;
                button.clicked();
            }
        }
    }

    component PillButton: Rectangle {
        id: button

        property string label: ""
        property bool active: false
        property color accent: TuiStyle.accent
        signal clicked()

        implicitWidth: Math.max(46, labelText.implicitWidth + 20)
        implicitHeight: 28
        width: implicitWidth
        height: implicitHeight
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        radius: 5
        color: buttonMouse.pressed ? TuiStyle.surfacePressed
            : buttonMouse.containsMouse ? TuiStyle.surfaceHover
            : (active ? Qt.rgba(accent.r, accent.g, accent.b, 0.14) : "transparent")
        border.width: active ? TuiStyle.borderWidth : 0
        border.color: active ? TuiStyle.shellBorder : "transparent"
        opacity: enabled ? 1 : 0.4

        StyledText {
            id: labelText
            anchors.centerIn: parent
            text: button.label
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: button.active ? button.accent : TuiStyle.dim
            elide: Text.ElideRight
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            enabled: button.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                mouse.accepted = true;
                button.clicked();
            }
        }
    }
}
