pragma ComponentBehavior: Bound
import qs
import qs.core.runtime
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: root
    property var notificationObject
    property bool expanded: false
    property bool onlyNotification: false
    property real fontSize: Appearance.font.pixelSize.small
    property real horizontalPadding: 12
    property real verticalPadding: 10
    readonly property bool critical: notificationObject?.urgency == NotificationUrgency.Critical
        || notificationObject?.urgency == NotificationUrgency.Critical.toString()
    readonly property bool hovered: hoverHandler.hovered
    readonly property bool hasBody: (notificationObject?.body || "").length > 0
    readonly property bool hasActions: (notificationObject?.actions?.length ?? 0) > 0
    readonly property string displayApp: notificationObject?.appName || "notification"

    implicitHeight: rowBackground.implicitHeight

    function discard() {
        ServiceManager.notification.discardNotification(notificationObject.notificationId);
    }

    function bodyText() {
        return NotificationUtils.processNotificationBody(
            notificationObject?.body || "",
            notificationObject?.appName || notificationObject?.summary || ""
        );
    }

    HoverHandler {
        id: hoverHandler
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: root.discard()
    }

    Rectangle {
        id: rowBackground
        width: parent.width
        radius: 8
        color: "transparent"
        border.width: 0
        implicitHeight: contentRow.implicitHeight + root.verticalPadding * 2

        RowLayout {
            id: contentRow
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: root.horizontalPadding
                rightMargin: root.horizontalPadding
            }
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
                urgency: root.critical ? NotificationUrgency.Critical : NotificationUrgency.Normal
            }

            // Middle: summary + body
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 3

                // Summary
                StyledText {
                    Layout.fillWidth: true
                    text: root.notificationObject?.summary || ""
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.family: Appearance.font.family.main
                    font.weight: Font.DemiBold
                    color: root.critical ? TuiStyle.danger : TuiStyle.fg
                    textFormat: Text.PlainText
                }

                // Body
                StyledText {
                    Layout.fillWidth: true
                    visible: root.hasBody && root.bodyText() !== (root.notificationObject?.summary || "")
                    text: root.bodyText().replace(/\n/g, " ")
                    maximumLineCount: 2
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
                        id: timeText
                        anchors.centerIn: parent
                        visible: !root.hovered
                        text: NotificationUtils.getFriendlyNotifTimeString(notificationObject?.time)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.family: Appearance.font.family.monospace
                        color: TuiStyle.dim
                        opacity: 0.7
                    }

                    RowLayout {
                        id: timeOrButtons
                        anchors.centerIn: parent
                        visible: root.hovered
                        spacing: 4

                    Rectangle {
                        id: copyBtn
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: 5
                        visible: root.hasBody || (root.notificationObject?.summary || "").length > 0
                        color: copyArea.pressed ? TuiStyle.surfacePressed
                            : copyArea.containsMouse ? TuiStyle.surfaceHover
                            : "transparent"

                        QtObject {
                            id: copyState
                            property string label: "content_copy"
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: copyState.label
                            iconSize: 18
                            color: TuiStyle.dim
                        }

                        MouseArea {
                            id: copyArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.clipboardText = root.notificationObject?.body || root.notificationObject?.summary || "";
                                copyState.label = "check";
                                copyReset.restart();
                            }
                        }

                        Timer {
                            id: copyReset
                            interval: 1500
                            repeat: false
                            onTriggered: copyState.label = "content_copy"
                        }
                    }

                    Rectangle {
                        id: muteBtn
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: 5
                        color: muteMouse.pressed ? TuiStyle.surfacePressed
                            : muteMouse.containsMouse ? TuiStyle.surfaceHover
                            : "transparent"

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: ServiceManager.notification.isMuted(root.displayApp, notificationObject?.summary, notificationObject?.body) ? "notifications_off" : "notifications"
                            iconSize: 18
                            color: ServiceManager.notification.isMuted(root.displayApp, notificationObject?.summary, notificationObject?.body) ? TuiStyle.danger : TuiStyle.dim
                        }

                        MouseArea {
                            id: muteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ServiceManager.notification.toggleMuteApp(root.displayApp, notificationObject?.summary)
                        }
                    }

                    Rectangle {
                        id: closeBtn
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: 5
                        color: closeArea.pressed ? TuiStyle.surfacePressed
                            : closeArea.containsMouse ? TuiStyle.surfaceHover
                            : "transparent"

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "delete"
                            iconSize: 18
                            color: TuiStyle.danger
                        }

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.discard()
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}}
