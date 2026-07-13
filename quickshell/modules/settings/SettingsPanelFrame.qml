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

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            frame.settingsRoot.dismiss();
            event.accepted = true;
        }
    }

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

            // Confirm button
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                color: "transparent"

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    anchors.top: parent.top
                    color: SettingsTokens.line
                    opacity: 0.55
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 120
                    height: 32
                    radius: TuiStyle.radius
                    color: confirmMouse.containsMouse ? SettingsTokens.accent : SettingsTokens.card
                    border.width: 1
                    border.color: SettingsTokens.accent

                    StyledText {
                        anchors.centerIn: parent
                        text: "Confirm"
                        color: confirmMouse.containsMouse ? SettingsTokens.bg : SettingsTokens.accent
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: confirmMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: frame.settingsRoot.dismiss()
                    }
                }
            }
        }
    }
}
