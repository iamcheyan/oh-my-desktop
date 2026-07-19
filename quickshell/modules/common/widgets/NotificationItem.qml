import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

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
        Notifications.discardNotification(notificationObject.notificationId);
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

            // Right: time + buttons stacked
            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: 6

                StyledText {
                    Layout.alignment: Qt.AlignRight
                    text: NotificationUtils.getFriendlyNotifTimeString(notificationObject?.time)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.family: Appearance.font.family.monospace
                    color: TuiStyle.dim
                    opacity: 0.7
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    visible: root.hovered
                    spacing: 4

                    Rectangle {
                        id: muteBtn
                        implicitWidth: 28
                        implicitHeight: 26
                        radius: TuiStyle.miniRadius
                        color: "transparent"
                        border.width: 1
                        border.color: TuiStyle.line

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: Notifications.isMuted(root.displayApp) ? "notifications_off" : "notifications"
                            iconSize: 16
                            color: Notifications.isMuted(root.displayApp) ? TuiStyle.danger : TuiStyle.dim
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifications.toggleMuteApp(root.displayApp)
                        }
                    }

                    Rectangle {
                        id: closeBtn
                        implicitWidth: 44
                        implicitHeight: 26
                        radius: TuiStyle.miniRadius
                        color: "transparent"
                        border.width: 1
                        border.color: TuiStyle.line

                        StyledText {
                            anchors.centerIn: parent
                            text: "close"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: TuiStyle.dim
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.discard()
                        }
                    }

                    Rectangle {
                        id: copyBtn
                        implicitWidth: 44
                        implicitHeight: 26
                        radius: TuiStyle.miniRadius
                        visible: root.hasBody || (root.notificationObject?.summary || "").length > 0
                        color: "transparent"
                        border.width: 1
                        border.color: TuiStyle.line

                        QtObject {
                            id: copyState
                            property string label: "copy"
                        }

                        StyledText {
                            anchors.centerIn: parent
                            text: copyState.label
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: TuiStyle.dim
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.clipboardText = root.notificationObject?.body || root.notificationObject?.summary || "";
                                copyState.label = "copied";
                                copyReset.restart();
                            }
                        }

                        Timer {
                            id: copyReset
                            interval: 1500
                            repeat: false
                            onTriggered: copyState.label = "copy"
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}