import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import qs.modules.settings.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: frame

    required property var settingsRoot
    property string title: "Settings"
    property string iconName: "settings"
    property Component pageComponent

    Rectangle {
        anchors.fill: parent
        color: TuiStyle.bg
        radius: 0
        border.width: TuiStyle.borderWidth
        border.color: TuiStyle.shellBorder
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: frame.settingsRoot.shellInset
            spacing: 0

            // Close button only
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                color: "transparent"

                SettingsIconButton {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "close"
                    onClicked: frame.settingsRoot.dismiss()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: SettingsTokens.line
                opacity: 0.55
            }

            StyledFlickable {
                id: pageScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: pageLoader.item
                    ? pageLoader.item.implicitHeight + frame.settingsRoot.pageInset * 2
                    : 0

                Loader {
                    id: pageLoader
                    x: frame.settingsRoot.pageInset
                    y: frame.settingsRoot.pageInset
                    width: Math.max(0, pageScroll.width - frame.settingsRoot.pageInset * 2)
                    sourceComponent: frame.pageComponent

                    onLoaded: {
                        if (item && item.settingsRoot !== undefined)
                            item.settingsRoot = frame.settingsRoot;
                    }
                }
            }
        }
    }
}
