pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property string title: ""
    property string description: ""
    property string actionLabel: ""
    property string actionIcon: "warning"
    property bool confirmOpen: false
    signal actionClicked()

    Layout.fillWidth: true
    implicitHeight: dangerColumn.implicitHeight + 24
    radius: SettingsTokens.roundRadius
    color: SettingsTokens.warningPanel
    border.width: 1
    border.color: SettingsTokens.warningBorder

    ColumnLayout {
        id: dangerColumn
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        StyledText {
            visible: root.title.length > 0
            Layout.fillWidth: true
            text: root.title
            color: SettingsTokens.fg
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        StyledText {
            visible: root.description.length > 0
            Layout.fillWidth: true
            text: root.description
            color: SettingsTokens.muted
            font.pixelSize: Appearance.font.pixelSize.smaller
            wrapMode: Text.WordWrap
        }

        RowLayout {
            visible: root.actionLabel.length > 0
            spacing: 8

            Rectangle {
                Layout.preferredWidth: actionText.implicitWidth + 24
                Layout.preferredHeight: 36
                radius: SettingsTokens.radius
                color: actionMouse.containsMouse ? "#4a3030" : "#3a2020"
                border.width: 1
                border.color: "#5a3030"

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        visible: root.actionIcon.length > 0
                        text: root.actionIcon
                        iconSize: 16
                        color: "#f07070"
                    }

                    StyledText {
                        id: actionText
                        text: root.confirmOpen ? "Confirm" : root.actionLabel
                        color: "#f07070"
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                    }
                }

                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.confirmOpen) {
                            root.actionClicked();
                            root.confirmOpen = false;
                        } else {
                            root.confirmOpen = true;
                        }
                    }
                }
            }

            Rectangle {
                visible: root.confirmOpen
                Layout.preferredWidth: cancelText.implicitWidth + 24
                Layout.preferredHeight: 36
                radius: SettingsTokens.radius
                color: cancelMouse.containsMouse ? SettingsTokens.buttonHover : SettingsTokens.button
                border.width: 1
                border.color: SettingsTokens.buttonBorder

                StyledText {
                    id: cancelText
                    anchors.centerIn: parent
                    text: "Cancel"
                    color: SettingsTokens.fg
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: cancelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.confirmOpen = false
                }
            }
        }
    }
}
