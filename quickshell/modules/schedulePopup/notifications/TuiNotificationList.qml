import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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

    property bool showFooterDnd: true

    readonly property int headerGap: showHeader ? 10 : 0
    readonly property int footerGap: showFooter ? 10 : 0
    readonly property int listHeight: Math.max(112, Math.min(maxListHeight, listView.contentHeight))

    implicitHeight: listHeight + headerGap + footerGap
    implicitWidth: 360

    onVisibleChanged: {
        if (visible && markReadOnVisible)
            Notifications.markAllRead();
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

    function sortedNotifications() {
        return Notifications.list.slice().sort((a, b) => b.time - a.time);
    }

    ColumnLayout {
        id: column
        anchors {
            left: parent ? parent.left : undefined
            right: parent ? parent.right : undefined
            top: parent ? parent.top : undefined
            bottom: parent ? parent.bottom : undefined
            leftMargin: 16
            rightMargin: 16
        }
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
                            : `${Notifications.appNameList.length} app${Notifications.appNameList.length === 1 ? "" : "s"} · ${Notifications.list.length} notification${Notifications.list.length === 1 ? "" : "s"}`)
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

            IconButton {
                symbol: "settings"
                tooltip: "Muted apps"
                onClicked: Notifications.openMutedAppsEditor()
            }
        }
    }

        Item {
            id: listHost
            Layout.fillWidth: true
            Layout.preferredHeight: root.listHeight
            Layout.topMargin: root.headerGap
            implicitHeight: root.listHeight

            ListView {
                id: listView
                anchors.fill: parent
                clip: true
                spacing: root.hubStyle ? 0 : 4
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: StyledScrollBar {}
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
            opacity: 0.10
        }

        RowLayout {
            anchors.fill: parent
            anchors.topMargin: 10
            spacing: 10

            StyledText {
                visible: root.showFooterDnd
                text: "Do Not Disturb"
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.small
                color: TuiStyle.fg
            }

            TuiToggle {
                visible: root.showFooterDnd
                checked: Notifications.silent
                onToggled: Notifications.silent = !Notifications.silent
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                implicitWidth: Math.max(88, clearLabel.implicitWidth + 24)
                implicitHeight: 32
                radius: TuiStyle.radius
                color: clearMouse.pressed ? TuiStyle.controlHover
                    : clearMouse.containsMouse ? TuiStyle.controlHover
                    : TuiStyle.control
                border.width: 0
                opacity: Notifications.list.length > 0 ? 1 : 0.45

                StyledText {
                    id: clearLabel
                    anchors.centerIn: parent
                    text: "Clear All"
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
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

    function openMutedEditor() {
        Quickshell.execDetached([`${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-edit-muted-apps`]);
    }

    component TuiToggle: Rectangle {
        id: toggle

        property bool checked: false
        signal toggled()

        implicitWidth: 46
        implicitHeight: 26
        radius: height / 2
        color: checked ? TuiStyle.accent : TuiStyle.controlMuted
        border.width: TuiStyle.borderWidth
        border.color: checked ? TuiStyle.shellBorder : TuiStyle.line

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Rectangle {
            width: 20
            height: 20
            radius: 10
            anchors.verticalCenter: parent.verticalCenter
            x: toggle.checked ? parent.width - width - 3 : 3
            color: toggle.checked ? TuiStyle.bg : TuiStyle.fg

            Behavior on x {
                NumberAnimation { duration: 110 }
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
            ? hubContent.implicitHeight + 12
            : standardContent.implicitHeight + 12
        height: implicitHeight
        radius: 6
        color: "transparent"
        border.width: 0

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

        // ── Hub style (compact, for OSK/sidebar) ──
        RowLayout {
            id: hubContent
            visible: row.hubStyle
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            NotificationAppIcon {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                scale: 22 / 38
                appIcon: notificationObject?.appIcon || ""
                image: notificationObject?.image || ""
                summary: notificationObject?.summary || ""
                urgency: row.critical ? NotificationUrgency.Critical : NotificationUrgency.Normal
            }

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
                text: notificationObject?.summary || ""
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
                color: TuiStyle.fg
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

        // ── Standard style (three-column: icon | content | time+buttons) ──
        RowLayout {
            id: standardContent
            visible: !row.hubStyle
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 10

            // Left: icon
            NotificationAppIcon {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 2
                scale: 40 / 38
                appIcon: notificationObject?.appIcon || ""
                image: notificationObject?.image || ""
                summary: notificationObject?.summary || ""
                urgency: row.critical ? NotificationUrgency.Critical : NotificationUrgency.Normal
            }

            // Middle: summary + body
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 3

                StyledText {
                    Layout.fillWidth: true
                    text: notificationObject?.summary || row.displayApp
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.family: Appearance.font.family.main
                    font.weight: Font.DemiBold
                    color: row.critical ? TuiStyle.danger : TuiStyle.fg
                    textFormat: Text.PlainText
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: row.hasBody && (row.expanded || (notificationObject?.summary || "") !== row.bodyText())
                    text: row.bodyText().replace(/\n/g, " ")
                    maximumLineCount: row.expanded ? 5 : 1
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.family: Appearance.font.family.main
                    color: TuiStyle.dim
                    textFormat: Text.PlainText
                }
            }

            // Right: time / buttons — same slot, no height change
            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: 0

                Item {
                    Layout.alignment: Qt.AlignRight
                    implicitWidth: timeOrButtons.implicitWidth
                    implicitHeight: 28

                    StyledText {
                        anchors.centerIn: parent
                        visible: !rowHover.hovered
                        text: NotificationUtils.getFriendlyNotifTimeString(notificationObject?.time)
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: 9
                        color: TuiStyle.dim
                        opacity: 0.7
                    }

                    RowLayout {
                        id: timeOrButtons
                        anchors.centerIn: parent
                        visible: rowHover.hovered
                        spacing: 4

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
                            symbol: Notifications.isMuted(row.displayApp, notificationObject?.summary, notificationObject?.body) ? "notifications_off" : "notifications"
                            tooltip: Notifications.isMuted(row.displayApp, notificationObject?.summary, notificationObject?.body) ? "Unmute app" : "Mute app"
                            danger: Notifications.isMuted(row.displayApp, notificationObject?.summary, notificationObject?.body)
                            onClicked: Notifications.toggleMuteApp(row.displayApp, notificationObject?.summary)
                        }

                        IconButton {
                            symbol: "close"
                            tooltip: "Dismiss"
                            danger: true
                            onClicked: row.discard()
                        }
                    }
                }

                Item { Layout.fillHeight: true }
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
