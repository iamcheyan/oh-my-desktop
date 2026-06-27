pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: root
    signal menuClosed

    color: "transparent"
    property real padding: Appearance.sizes.elevationMargin

    readonly property color tuiBg: "#030806"
    readonly property color tuiPanel: "#06110e"
    readonly property color tuiPanelAlt: "#091814"
    readonly property color tuiFg: "#e8fff3"
    readonly property color tuiDim: "#65736e"
    readonly property color tuiLine: "#174339"
    readonly property color tuiGreen: "#36ff8b"
    readonly property color tuiYellow: "#e8ff82"
    readonly property color tuiBlue: "#7bc7ff"
    readonly property color tuiPurple: "#c792ea"
    readonly property color tuiRed: "#ff6b8b"

    readonly property string serviceName: Cliphist.cliphistBinary
    readonly property int entryCount: Cliphist.entries.length
    readonly property bool serviceReady: entryCount > 0 || Cliphist.cliphistBinary.length > 0

    implicitWidth: popupBg.implicitWidth + padding * 2
    implicitHeight: popupBg.implicitHeight + padding * 2

    function close() {
        root.visible = false;
        root.menuClosed();
    }

    Component.onCompleted: {
        GlobalFocusGrab.addDismissable(root);
    }
    Component.onDestruction: {
        GlobalFocusGrab.removeDismissable(root);
    }

    Connections {
        target: GlobalFocusGrab
        function onDismissed() {
            root.close();
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.close()

        StyledRectangularShadow {
            target: popupBg
            opacity: popupBg.opacity
        }

        Rectangle {
            id: popupBg
            readonly property real innerPad: 12
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: root.padding
            }

            color: root.tuiBg
            radius: Appearance.tiling.dialogRadius
            border.width: Appearance.tiling.borderWidth
            border.color: root.tuiLine
            clip: true

            opacity: 0
            Component.onCompleted: opacity = 1
            implicitWidth: 300 + innerPad * 2
            implicitHeight: popupCol.implicitHeight + innerPad * 2

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
            Behavior on implicitHeight {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
            }

            ColumnLayout {
                id: popupCol
                anchors {
                    fill: parent
                    margins: popupBg.innerPad
                }
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: root.tuiPanel
                    border.width: 1
                    border.color: root.tuiPurple

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 8

                        StyledText {
                            text: "CLIPBOARD"
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Bold
                            color: root.tuiPurple
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: root.tuiLine
                        }

                        StyledText {
                            text: root.serviceReady ? "READY" : "UNAVAILABLE"
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Bold
                            color: root.serviceReady ? root.tuiGreen : root.tuiRed
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    anchors.margins: 14
                    spacing: 14

                    DetailRow {
                        Layout.topMargin: 14
                        keyText: "SERVICE"
                        valueText: root.serviceName
                        valueColor: root.tuiPurple
                    }

                    DetailRow {
                        keyText: "STATUS"
                        valueText: root.serviceReady ? "active" : "inactive"
                        valueColor: root.serviceReady ? root.tuiGreen : root.tuiRed
                    }

                    DetailRow {
                        keyText: "ENTRIES"
                        valueText: `${root.entryCount}`
                        valueColor: root.tuiBlue
                    }

                    DetailRow {
                        keyText: "DELAY"
                        valueText: `${Math.round(Cliphist.pasteDelay * 1000)}ms`
                        valueColor: root.tuiDim
                    }

                    Item { Layout.preferredHeight: 8 }
                }
            }
        }
    }

    component DetailRow: RowLayout {
        property string keyText: ""
        property string valueText: ""
        property color valueColor: root.tuiFg

        Layout.fillWidth: true
        spacing: 10

        StyledText {
            Layout.preferredWidth: 70
            text: keyText
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.Bold
            color: root.tuiDim
        }

        StyledText {
            Layout.fillWidth: true
            text: valueText
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.Bold
            color: valueColor
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }
}