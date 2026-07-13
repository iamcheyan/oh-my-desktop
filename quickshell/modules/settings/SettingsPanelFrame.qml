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
        radius: TuiStyle.shellRadius
        border.width: TuiStyle.borderWidth
        border.color: TuiStyle.shellBorder
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: frame.settingsRoot.shellInset
            spacing: 0

            Rectangle {
                id: titleBar
                Layout.fillWidth: true
                Layout.preferredHeight: 66
                radius: TuiStyle.shellRadius - frame.settingsRoot.shellInset
                color: SettingsTokens.bg

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    property real pressX: 0
                    property real pressY: 0

                    onPressed: mouse => {
                        pressX = mouse.x;
                        pressY = mouse.y;
                        frame.settingsRoot.dragging = true;
                    }
                    onPositionChanged: mouse => {
                        if (pressed) {
                            frame.settingsRoot.dragOffsetX += mouse.x - pressX;
                            frame.settingsRoot.dragOffsetY += mouse.y - pressY;
                        }
                    }
                    onReleased: frame.settingsRoot.dragging = false
                    onCanceled: frame.settingsRoot.dragging = false
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 14
                    spacing: 12

                    MaterialSymbol {
                        text: frame.iconName
                        iconSize: 21
                        color: SettingsTokens.accent
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: frame.title
                        color: SettingsTokens.fg
                        font.pixelSize: Appearance.font.pixelSize.huge
                        font.weight: Font.DemiBold
                    }

                    SettingsIconButton {
                        iconName: "close"
                        onClicked: frame.settingsRoot.dismiss()
                    }
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
