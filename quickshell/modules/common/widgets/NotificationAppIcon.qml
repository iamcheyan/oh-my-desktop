pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

Item { // App icon
    id: root
    property var appIcon: ""
    property var summary: ""
    property var urgency: NotificationUrgency.Normal
    property bool isUrgent: urgency === NotificationUrgency.Critical
    property var image: ""
    readonly property string resolvedAppIcon: root.appIcon === "network-transmit" ? "" : root.appIcon
    readonly property string resolvedImage: root.image === "image://icon/network-transmit" ? "" : root.image
    property real materialIconScale: 0.57
    property real appIconScale: 0.8
    readonly property real baseSize: 38 * scale
    property real materialIconSize: baseSize * materialIconScale
    property real appIconSize: baseSize * appIconScale
    property real smallAppIconSize: baseSize * 0.49

    implicitWidth: baseSize
    implicitHeight: baseSize

    Loader {
        id: materialSymbolLoader
        active: root.resolvedAppIcon == "" && root.resolvedImage == ""
        anchors.fill: parent
        sourceComponent: Item {
            anchors.fill: parent

            MaterialSymbol {
                anchors.centerIn: parent
                text: {
                    const defaultIcon = NotificationUtils.findSuitableMaterialSymbol("")
                    const guessedIcon = NotificationUtils.findSuitableMaterialSymbol(root.summary)
                    return (root.urgency == NotificationUrgency.Critical && guessedIcon === defaultIcon) ?
                        "priority_high" : guessedIcon
                }
                iconSize: root.materialIconSize
                color: isUrgent ? Appearance.colors.colError : Qt.rgba(0.5, 0.5, 0.5, 0.6)
            }
        }
    }
    Loader {
        id: appIconLoader
        active: root.resolvedImage == "" && root.resolvedAppIcon != ""
        anchors.centerIn: parent
        sourceComponent: IconImage {
            id: appIconImage
            implicitSize: root.appIconSize
            asynchronous: true
            source: AppSearch.iconSource(root.resolvedAppIcon)
        }
    }
    Loader {
        id: notifImageLoader
        active: root.resolvedImage != ""
        anchors.fill: parent
        sourceComponent: Item {
            anchors.fill: parent
            StyledImage {
                id: notifImage
                anchors.fill: parent
                readonly property int size: parent.width

                source: root.resolvedImage
                fillMode: Image.PreserveAspectCrop
                cache: false
                antialiasing: true
                asynchronous: true
            }
            Loader {
                id: notifImageAppIconLoader
                active: root.resolvedAppIcon != ""
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                sourceComponent: IconImage {
                    implicitSize: root.smallAppIconSize
                    asynchronous: true
                    source: AppSearch.iconSource(root.resolvedAppIcon)
                }
            }
        }
    }
}
