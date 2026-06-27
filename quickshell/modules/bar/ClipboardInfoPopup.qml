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
    signal manageRequested

    color: "transparent"
    property real padding: Appearance.sizes.elevationMargin

    readonly property color tuiBg: TuiStyle.bg
    readonly property color tuiPanel: TuiStyle.panel
    readonly property color tuiPanelAlt: TuiStyle.panelAlt
    readonly property color tuiFg: TuiStyle.fg
    readonly property color tuiDim: TuiStyle.dim
    readonly property color tuiLine: TuiStyle.line
    readonly property color tuiGreen: TuiStyle.green
    readonly property color tuiYellow: TuiStyle.yellow
    readonly property color tuiBlue: TuiStyle.blue
    readonly property color tuiPurple: TuiStyle.purple
    readonly property color tuiRed: TuiStyle.red

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

                    TuiDetailRow {
                        Layout.topMargin: 14
                        keyText: "SERVICE"
                        valueText: root.serviceName
                        valueColor: root.tuiPurple
                    }

                    TuiDetailRow {
                        keyText: "STATUS"
                        valueText: root.serviceReady ? "active" : "inactive"
                        valueColor: root.serviceReady ? root.tuiGreen : root.tuiRed
                    }

                    TuiDetailRow {
                        keyText: "ENTRIES"
                        valueText: `${root.entryCount}`
                        valueColor: root.tuiBlue
                    }

                    TuiDetailRow {
                        keyText: "DELAY"
                        valueText: `${Math.round(Cliphist.pasteDelay * 1000)}ms`
                        valueColor: root.tuiDim
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: TuiStyle.borderWidth
                        color: root.tuiLine
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Item { Layout.fillWidth: true }

                        TuiActionButton {
                            label: "HISTORY"
                            accent: root.tuiGreen
                            onClicked: {
                                root.manageRequested();
                                root.close();
                            }
                        }
                    }
                }
            }
        }
    }

}
