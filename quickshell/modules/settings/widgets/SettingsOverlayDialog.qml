import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings

Item {
    id: root

    property bool show: false
    property string title: ""
    property string subtitle: ""
    property int dialogWidth: 520
    property int dialogHeight: 480
    property real dragOffsetX: 0
    property real dragOffsetY: 0
    property var hostShell: null

    signal dismissed()

    Layout.fillWidth: false
    Layout.preferredWidth: 0
    Layout.preferredHeight: 0

    function open() {
        dragOffsetX = 0
        dragOffsetY = 0
        if (hostShell) {
            parent = hostShell
            anchors.fill = hostShell
        }
        show = true
        Qt.callLater(() => dialog.forceActiveFocus())
    }

    function close() {
        show = false
        dismissed()
    }

    visible: show
    z: 200
    opacity: show ? 1 : 0

    Behavior on opacity {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: root.close()
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.48)
    }

    FocusScope {
        id: dialog
        x: parent.width / 2 - width / 2 + root.dragOffsetX
        y: parent.height / 2 - height / 2 + root.dragOffsetY
        width: Math.min(root.dialogWidth, parent.width - 48)
        height: Math.min(root.dialogHeight, parent.height - 48)
        focus: root.show

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.close()
                event.accepted = true
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: TuiStyle.shellRadius
            color: TuiStyle.bg
            border.width: TuiStyle.borderWidth
            border.color: TuiStyle.shellBorder
            clip: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    color: TuiStyle.panel

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        property real pressX: 0
                        property real pressY: 0
                        property real startX: 0
                        property real startY: 0

                        onPressed: mouse => {
                            pressX = mouse.x
                            pressY = mouse.y
                            startX = root.dragOffsetX
                            startY = root.dragOffsetY
                            dialog.forceActiveFocus()
                        }

                        onPositionChanged: mouse => {
                            if (!pressed) return
                            root.dragOffsetX = startX + (mouse.x - pressX)
                            root.dragOffsetY = startY + (mouse.y - pressY)
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 8
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                text: root.title
                                font.family: Appearance.font.family.main
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.DemiBold
                                color: TuiStyle.fg
                            }

                            StyledText {
                                visible: root.subtitle.length > 0
                                text: root.subtitle
                                font.family: Appearance.font.family.main
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: TuiStyle.dim
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: SettingsTokens.radius
                            color: closeMouse.containsMouse ? SettingsTokens.panelAlt : "transparent"

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "close"
                                iconSize: 18
                                color: closeMouse.containsMouse ? SettingsTokens.accent : SettingsTokens.muted
                            }

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.close()
                            }
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: TuiStyle.line
                        opacity: TuiStyle.dividerOpacity
                    }
                }

                StyledFlickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: contentCol.implicitHeight + 16
                    clip: true

                    ColumnLayout {
                        id: contentCol
                        width: parent.width
                        spacing: 14
                    }
                }
            }
        }
    }
}