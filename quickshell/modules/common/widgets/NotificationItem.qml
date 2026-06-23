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
    property real horizontalPadding: 8
    property real verticalPadding: 6
    readonly property bool critical: notificationObject?.urgency == NotificationUrgency.Critical
        || notificationObject?.urgency == NotificationUrgency.Critical.toString()
    readonly property bool hovered: hoverHandler.hovered

    implicitHeight: rowBackground.implicitHeight

    function discard() {
        Notifications.discardNotification(notificationObject.notificationId);
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
        radius: 0
        color: root.expanded ? Appearance.tiling.bgActive
            : root.hovered ? Appearance.tiling.bgHover
            : "transparent"
        implicitHeight: contentColumn.implicitHeight + root.verticalPadding * 2

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: root.critical ? 2 : 0
            color: Appearance.tiling.error
        }

        ColumnLayout {
            id: contentColumn
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: root.horizontalPadding + (root.critical ? 6 : 0)
                rightMargin: root.horizontalPadding
            }
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    text: root.notificationObject?.summary || ""
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.pixelSize: root.fontSize
                    font.family: Appearance.font.family.monospace
                    color: root.critical ? Appearance.tiling.error : Appearance.tiling.textBright
                    textFormat: Text.PlainText
                }

                StyledText {
                    visible: root.notificationObject?.actions?.length > 0
                    text: `[${root.notificationObject?.actions?.length ?? 0}]`
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.family: Appearance.font.family.monospace
                    color: Appearance.tiling.textDim
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: (root.notificationObject?.body || "").length > 0
                text: NotificationUtils.processNotificationBody(
                    root.notificationObject?.body || "",
                    root.notificationObject?.appName || root.notificationObject?.summary || ""
                ).replace(/\n/g, root.expanded ? "<br/>" : " ")
                maximumLineCount: root.expanded ? 999 : 1
                wrapMode: root.expanded ? Text.Wrap : Text.NoWrap
                elide: Text.ElideRight
                font.pixelSize: root.fontSize
                font.family: Appearance.font.family.monospace
                color: Appearance.tiling.text
                textFormat: root.expanded ? Text.RichText : Text.StyledText
                onLinkActivated: link => {
                    Qt.openUrlExternally(link);
                    GlobalStates.sidebarRightOpen = false;
                }
                PointingHandLinkHover {}
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 5
                visible: root.expanded
                spacing: 4

                NotificationActionButton {
                    buttonText: "close"
                    urgency: root.notificationObject?.urgency
                    onClicked: root.discard()
                }

                Repeater {
                    model: root.notificationObject?.actions ?? []
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

                NotificationActionButton {
                    id: copyButton
                    buttonText: "copy"
                    urgency: root.notificationObject?.urgency
                    onClicked: {
                        Quickshell.clipboardText = root.notificationObject?.body || "";
                        copyButton.buttonText = "copied";
                        copyTimer.restart();
                    }

                    Timer {
                        id: copyTimer
                        interval: 1500
                        repeat: false
                        onTriggered: copyButton.buttonText = "copy"
                    }
                }
            }
        }

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: 1
            color: Appearance.tiling.border
            opacity: root.expanded ? 0 : 0.55
        }
    }
}
