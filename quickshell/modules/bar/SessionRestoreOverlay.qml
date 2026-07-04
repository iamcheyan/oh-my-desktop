pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property string sessionCommand: "omd-session"
    property string restoreAction: "restore"
    property int expectedCount: 0
    property int restoredCount: 0
    property string statusText: expectedCount > 0 ? `Restoring ${expectedCount} windows` : "Restoring workspace snapshot"

    signal finished()

    Component.onCompleted: {
        restoreProc.running = true;
        elapsedTimer.start();
    }

    Process {
        id: restoreProc
        command: [root.sessionCommand, root.restoreAction]
        running: false

        stdout: StdioCollector {
            id: restoreStdout
            onStreamFinished: {
                try {
                    const data = JSON.parse(restoreStdout.text);
                    root.restoredCount = data.restored || 0;
                } catch (e) {
                    root.restoredCount = 0;
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            root.statusText = exitCode === 0
                ? "Arranging workspaces"
                : "Restore finished with errors";
            finishTimer.start();
        }
    }

    Timer {
        id: elapsedTimer
        interval: 450
        repeat: true
        onTriggered: pulseDot.dotCount = (pulseDot.dotCount + 1) % 4
    }

    Timer {
        id: finishTimer
        interval: 850
        repeat: false
        onTriggered: root.finished()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData
            visible: true
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "quickshell:session-restore"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.72)
            }

            Rectangle {
                id: glassNoise
                anchors.fill: parent
                color: TuiStyle.surfaceSubtle
                opacity: 0.18
            }

            Item {
                anchors.fill: parent

                StyledRectangularShadow {
                    target: restoreCard
                    opacity: 0.7
                }

                Rectangle {
                    id: restoreCard
                    width: Math.min(parent.width - 96, 460)
                    height: 188
                    anchors.centerIn: parent
                    radius: TuiStyle.shellRadius
                    color: TuiStyle.bg
                    border.width: TuiStyle.borderWidth
                    border.color: TuiStyle.shellBorder
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 16

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            NerdIcon {
                                text: NerdIconMap.workspaceSnapshot
                                iconSize: 28
                                color: TuiStyle.accent

                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 0.55; to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
                                    NumberAnimation { from: 1.0; to: 0.55; duration: 700; easing.type: Easing.InOutQuad }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.statusText + pulseDot.text
                                    color: TuiStyle.fg
                                    font.pixelSize: Appearance.font.pixelSize.large
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.restoredCount > 0
                                        ? `${root.restoredCount} windows launched`
                                        : "Launching saved applications behind this overlay"
                                    color: TuiStyle.muted
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: TuiStyle.line
                            opacity: TuiStyle.dividerOpacity
                        }

                        Rectangle {
                            id: progressTrack
                            Layout.fillWidth: true
                            Layout.preferredHeight: 10
                            radius: height / 2
                            color: TuiStyle.meterTrack
                            clip: true

                            Rectangle {
                                id: progressThumb
                                width: Math.max(80, progressTrack.width * 0.34)
                                height: parent.height
                                radius: height / 2
                                color: TuiStyle.accent
                                opacity: 0.85

                                SequentialAnimation on x {
                                    loops: Animation.Infinite
                                    NumberAnimation {
                                        from: -progressThumb.width
                                        to: progressTrack.width
                                        duration: 1050
                                        easing.type: Easing.InOutCubic
                                    }
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: "Windows will appear when restore is complete"
                            color: TuiStyle.muted
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }
            }
        }
    }

    QtObject {
        id: pulseDot
        property int dotCount: 0
        readonly property string text: dotCount === 0 ? "" : dotCount === 1 ? "." : dotCount === 2 ? ".." : "..."
    }
}
