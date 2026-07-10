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
    property bool showFooter: false
    property bool compactRows: false
    property bool hubStyle: false
    property bool markReadOnVisible: false
    property int maxListHeight: 360
    property var expandedRows: ({})

    readonly property int headerGap: showHeader ? 10 : 0
    readonly property int footerGap: showFooter ? 10 : 0
    readonly property int listHeight: Math.max(112, Math.min(maxListHeight, listView.contentHeight))

    implicitHeight: column.implicitHeight
    implicitWidth: column.implicitWidth

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

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: 0

    Rectangle {
        id: header
        Layout.fillWidth: true
        visible: root.showHeader
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

    Item {
        id: listHost
        Layout.fillWidth: true
        Layout.fillHeight: root.height > 0
        Layout.preferredHeight: root.height > 0 ? -1 : root.listHeight
        Layout.topMargin: root.headerGap
        implicitHeight: root.listHeight

        ListView {
            id: listView
            anchors.fill: parent
            clip: true
            spacing: root.hubStyle ? 0 : 8
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
                compactActions: root.compactRows && !root.hubStyle
                hubStyle: root.hubStyle
            }
        }

        Item {
            anchors.fill: parent
            visible: Notifications.list.length === 0
            z: 1

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
    }

    Item {
        id: footer
        Layout.fillWidth: true
        Layout.topMargin: root.footerGap
        visible: root.showFooter
        implicitHeight: visible ? (root.hubStyle ? 44 : 40) : 0

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: TuiStyle.line
            opacity: TuiStyle.dividerOpacity
        }

        RowLayout {
            anchors.fill: parent
            anchors.topMargin: 10
            spacing: 10

            StyledText {
                text: "Do Not Disturb"
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.small
                color: TuiStyle.fg
            }

            TuiToggle {
                checked: Notifications.silent
                onToggled: Notifications.silent = !Notifications.silent
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                implicitWidth: Math.max(78, clearLabel.implicitWidth + 20)
                implicitHeight: 28
                radius: 6
                color: clearMouse.pressed ? TuiStyle.surfacePressed
                    : clearMouse.containsMouse ? TuiStyle.surfaceHover
                    : TuiStyle.controlMuted
                border.width: root.hubStyle ? 0 : TuiStyle.borderWidth
                border.color: TuiStyle.line
                opacity: Notifications.list.length > 0 ? 1 : 0.45

                StyledText {
                    id: clearLabel
                    anchors.centerIn: parent
                    text: "Clear All"
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                    color: TuiStyle.fg
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    enabled: Notifications.list.length > 0
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifications.discardAllNotifications()
                }
            }
        }
    }

    } // column

    component TuiToggle: Rectangle {
        id: toggle

        property bool checked: false
        signal toggled()

        implicitWidth: 38
        implicitHeight: 20
        radius: 10
        color: checked ? TuiStyle.accent : TuiStyle.controlMuted
        border.width: TuiStyle.borderWidth
        border.color: checked ? TuiStyle.shellBorder : TuiStyle.line

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Rectangle {
            width: 12
            height: 12
            radius: 6
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: toggle.checked ? parent.width - width - 4 : 4
            color: toggle.checked ? TuiStyle.bg : TuiStyle.fg

            Behavior on anchors.leftMargin {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.toggled()
        }
    }

    component NotificationRow: Rectangle {
        id: row

        required property var notificationObject
        required property int rowIndex
        property bool compactActions: false
        property bool hubStyle: false
        readonly property bool critical: notificationObject?.urgency == NotificationUrgency.Critical
            || notificationObject?.urgency == NotificationUrgency.Critical.toString()
        readonly property bool expanded: root.isExpanded(notificationObject?.notificationId)
        readonly property bool hasBody: (notificationObject?.body || "").length > 0
        readonly property bool hasActions: (notificationObject?.actions?.length ?? 0) > 0
        readonly property string displayApp: notificationObject?.appName || "System"
        readonly property bool interactive: row.hasBody || row.hasActions

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

        implicitHeight: row.hubStyle
            ? hubRow.implicitHeight + 16
            : rowContent.implicitHeight + 24
        radius: row.hubStyle ? 0 : 8
        color: rowTap.pressed ? TuiStyle.surfacePressed
            : rowHover.hovered || expanded ? TuiStyle.surfaceHover
            : (row.hubStyle ? "transparent" : TuiStyle.surfaceSubtle)
        border.width: row.hubStyle ? 0 : TuiStyle.borderWidth
        border.color: critical ? TuiStyle.danger
            : rowHover.hovered || expanded ? TuiStyle.shellBorder
            : Qt.rgba(TuiStyle.shellBorder.r, TuiStyle.shellBorder.g, TuiStyle.shellBorder.b, 0.45)

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        HoverHandler {
            id: rowHover
            cursorShape: row.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        TapHandler {
            id: rowTap
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onTapped: (eventPoint, button) => {
                if (button === Qt.MiddleButton)
                    row.discard();
                else if (row.interactive)
                    root.toggleExpanded(row.notificationObject.notificationId);
            }
        }

        Rectangle {
            visible: !row.hubStyle
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: critical ? TuiStyle.borderWidth : 0
            radius: row.radius
            color: TuiStyle.danger
        }

        RowLayout {
            id: hubRow
            visible: row.hubStyle
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 2
            anchors.rightMargin: 2
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 8

            Item {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignTop

                NotificationAppIcon {
                    anchors.centerIn: parent
                    scale: 26 / 38
                    appIcon: notificationObject?.appIcon || ""
                    image: notificationObject?.image || ""
                    summary: notificationObject?.summary || ""
                    urgency: row.critical ? NotificationUrgency.Critical : NotificationUrgency.Normal
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        Layout.fillWidth: true
                        text: row.displayApp
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: TuiStyle.dim
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    StyledText {
                        text: NotificationUtils.getFriendlyNotifTimeString(notificationObject?.time)
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: TuiStyle.dim
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: notificationObject?.summary || row.displayApp
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: row.critical ? TuiStyle.danger : TuiStyle.fg
                    elide: Text.ElideRight
                    maximumLineCount: row.expanded ? 4 : 1
                    wrapMode: row.expanded ? Text.Wrap : Text.NoWrap
                    textFormat: Text.PlainText
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: row.hasBody && (row.expanded || (notificationObject?.summary || "") !== row.bodyText())
                    text: row.bodyText().replace(/\n/g, " ")
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: TuiStyle.dim
                    elide: Text.ElideRight
                    maximumLineCount: row.expanded ? 5 : 1
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                }
            }
        }

        Rectangle {
            visible: row.hubStyle
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: TuiStyle.line
            opacity: TuiStyle.dividerOpacity
        }

        ColumnLayout {
            id: rowContent
            visible: !row.hubStyle
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: critical ? 14 : 12
            anchors.rightMargin: 12
            anchors.topMargin: 12
            anchors.bottomMargin: 10
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

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

                StyledText {
                    Layout.fillWidth: true
                    text: row.displayApp
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                    color: TuiStyle.dim
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                StyledText {
                    text: NotificationUtils.getFriendlyNotifTimeString(notificationObject?.time)
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: TuiStyle.dim
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: notificationObject?.summary || row.displayApp
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: row.critical ? TuiStyle.danger : TuiStyle.fg
                elide: Text.ElideRight
                maximumLineCount: row.expanded ? 3 : 2
                wrapMode: row.expanded ? Text.Wrap : Text.NoWrap
                textFormat: Text.PlainText
            }

            StyledText {
                Layout.fillWidth: true
                visible: row.hasBody
                text: row.bodyText().replace(/\n/g, row.expanded ? "<br/>" : " ")
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.small
                color: TuiStyle.dim
                elide: Text.ElideRight
                maximumLineCount: row.expanded ? 8 : 2
                wrapMode: row.expanded ? Text.Wrap : Text.NoWrap
                textFormat: row.expanded ? Text.RichText : Text.StyledText
                onLinkActivated: link => {
                    Qt.openUrlExternally(link);
                    GlobalStates.barPopupType = "";
                }
                PointingHandLinkHover {}
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: row.hasBody || row.hasActions ? 2 : 0
                spacing: 6
                visible: !row.compactActions || rowHover.hovered || row.expanded
                opacity: visible ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 100 }
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

                Item {
                    Layout.fillWidth: true
                    visible: !(row.expanded && row.hasActions)
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
                    visible: row.interactive
                    enabled: row.interactive
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
