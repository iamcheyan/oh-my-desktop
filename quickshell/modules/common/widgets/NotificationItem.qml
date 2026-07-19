import qs
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
    property real horizontalPadding: onlyNotification ? 12 : 8
    property real verticalPadding: onlyNotification ? 10 : 6
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
        implicitHeight: contentColumn.implicitHeight + root.verticalPadding * 2

        ColumnLayout {
            id: contentColumn
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: root.horizontalPadding
                rightMargin: root.horizontalPadding
            }
            spacing: onlyNotification ? 6 : 2

            RowLayout {
                Layout.fillWidth: true
                visible: onlyNotification
                spacing: 8

                NotificationAppIcon {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    scale: 20 / 38
                    appIcon: notificationObject?.appIcon || ""
                    image: notificationObject?.image || ""
                    summary: notificationObject?.summary || ""
                    urgency: root.critical ? NotificationUrgency.Critical : NotificationUrgency.Normal
                }

                StyledText {
                    Layout.fillWidth: true
                    text: displayApp
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.family: Appearance.font.family.main
                    font.weight: Font.Medium
                    color: TuiStyle.dim
                }

                StyledText {
                    text: NotificationUtils.getFriendlyNotifTimeString(notificationObject?.time)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.family: Appearance.font.family.monospace
                    color: TuiStyle.dim
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    text: root.notificationObject?.summary || ""
                    elide: Text.ElideRight
                    maximumLineCount: onlyNotification ? (expanded ? 3 : 2) : 1
                    wrapMode: onlyNotification && expanded ? Text.Wrap : Text.NoWrap
                    font.pixelSize: onlyNotification ? Appearance.font.pixelSize.normal : root.fontSize
                    font.family: Appearance.font.family.main
                    font.weight: onlyNotification ? Font.DemiBold : Font.Normal
                    color: root.critical ? TuiStyle.danger : TuiStyle.fg
                    textFormat: Text.PlainText
                }

                StyledText {
                    visible: !onlyNotification && root.notificationObject?.actions?.length > 0
                    text: `[${root.notificationObject?.actions?.length ?? 0}]`
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.family: Appearance.font.family.monospace
                    color: TuiStyle.dim
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.hasBody
                text: root.bodyText().replace(/\n/g, root.expanded ? "<br/>" : " ")
                maximumLineCount: root.expanded ? 999 : (onlyNotification ? 3 : 1)
                wrapMode: root.expanded || onlyNotification ? Text.Wrap : Text.NoWrap
                elide: Text.ElideRight
                font.pixelSize: root.fontSize
                font.family: Appearance.font.family.main
                color: TuiStyle.dim
                textFormat: root.expanded ? Text.RichText : Text.StyledText
                onLinkActivated: link => {
                    Qt.openUrlExternally(link);
                    GlobalStates.barPopupType = "";
                }
                PointingHandLinkHover {}
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: onlyNotification ? 4 : 5
                visible: true
                spacing: 4

                Repeater {
                    model: root.expanded ? (root.notificationObject?.actions ?? []) : []
                    NotificationActionButton {
                        required property var modelData
                        buttonText: modelData.text
                        urgency: root.notificationObject?.urgency
                        onClicked: {
                            Notifications.attemptInvokeAction(root.notificationObject.notificationId, modelData.identifier);
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Rectangle {
                    id: closeBtn
                    implicitWidth: 52
                    implicitHeight: 24
                    radius: TuiStyle.miniRadius
                    color: "transparent"
                    border.width: 1
                    border.color: TuiStyle.line

                    StyledText {
                        anchors.centerIn: parent
                        text: "close"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: TuiStyle.dim
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.discard()
                    }
                }

                Rectangle {
                    id: copyBtn
                    implicitWidth: 52
                    implicitHeight: 24
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
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: TuiStyle.dim
                    }

                    MouseArea {
                        id: copyArea
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
        }
    }
}