import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: stopwatchTab
    Layout.fillWidth: true
    Layout.fillHeight: true

    Item {
        anchors {
            fill: parent
            topMargin: 8
            leftMargin: 16
            rightMargin: 16
        }

        RowLayout { // Elapsed
            id: elapsedIndicator
            
            anchors {
                top: undefined
                verticalCenter: parent.verticalCenter
                left: controlButtons.left
                leftMargin: 6
            }

            states: State {
                name: "hasLaps"
                when: TimerService.stopwatchLaps.length > 0
                AnchorChanges {
                    target: elapsedIndicator
                    anchors.top: parent.top
                    anchors.verticalCenter: undefined
                    anchors.left: controlButtons.left
                }
            }

            transitions: Transition {
                AnchorAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            spacing: 0
            StyledText {
                // Layout.preferredWidth: elapsedIndicator.width * 0.6 // Prevent shakiness
                font.family: Appearance.font.family.monospace
                font.pixelSize: 40
                color: "#e8fff3"
                text: {
                    let totalSeconds = Math.floor(TimerService.stopwatchTime) / 100
                    let minutes = Math.floor(totalSeconds / 60).toString().padStart(2, '0')
                    let seconds = Math.floor(totalSeconds % 60).toString().padStart(2, '0')
                    return `${minutes}:${seconds}`
                }
            }
            StyledText {
                Layout.fillWidth: true
                font.family: Appearance.font.family.monospace
                font.pixelSize: 40
                color: "#65736e"
                text: {
                    return `:<sub>${(Math.floor(TimerService.stopwatchTime) % 100).toString().padStart(2, '0')}</sub>`
                }
            }
        }

        // Laps
        StyledListView {
            id: lapsList
            anchors {
                top: elapsedIndicator.bottom
                bottom: controlButtons.top
                left: parent.left
                right: parent.right
                topMargin: 16
                bottomMargin: 16
            }
            spacing: 4
            clip: true
            popin: true

            model: ScriptModel {
                values: TimerService.stopwatchLaps.map((v, i, arr) => arr[arr.length - 1 - i])
            }

            delegate: Rectangle {
                id: lapItem
                required property int index
                required property var modelData
                property var horizontalPadding: 10
                property var verticalPadding: 6
                width: lapsList.width
                implicitHeight: lapRow.implicitHeight + verticalPadding * 2
                implicitWidth: lapRow.implicitWidth + horizontalPadding * 2
                color: "#06110e"
                radius: 0
                border.width: 1
                border.color: "#174339"

                RowLayout {
                    id: lapRow
                    anchors {
                        fill: parent
                        leftMargin: lapItem.horizontalPadding
                        rightMargin: lapItem.horizontalPadding
                        topMargin: lapItem.verticalPadding
                        bottomMargin: lapItem.verticalPadding
                    }

                    StyledText {
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: "#65736e"
                        text: `${TimerService.stopwatchLaps.length - lapItem.index}.`
                    }

                    StyledText {
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: "#e8fff3"
                        text: {
                            const lapTime = lapItem.modelData
                            const _10ms = (Math.floor(lapTime) % 100).toString().padStart(2, '0')
                            const totalSeconds = Math.floor(lapTime) / 100
                            const minutes = Math.floor(totalSeconds / 60).toString().padStart(2, '0')
                            const seconds = Math.floor(totalSeconds % 60).toString().padStart(2, '0')
                            return `${minutes}:${seconds}.${_10ms}`
                        }
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: "#7bc7ff"
                        text: {
                            const originalIndex = TimerService.stopwatchLaps.length - lapItem.index - 1
                            const lastTime = originalIndex > 0 ? TimerService.stopwatchLaps[originalIndex - 1] : 0
                            const lapTime = lapItem.modelData - lastTime
                            const _10ms = (Math.floor(lapTime) % 100).toString().padStart(2, '0')
                            const totalSeconds = Math.floor(lapTime) / 100
                            const minutes = Math.floor(totalSeconds / 60).toString().padStart(2, '0')
                            const seconds = Math.floor(totalSeconds % 60).toString().padStart(2, '0')
                            return `+${minutes == "00" ? "" : minutes + ":"}${seconds}.${_10ms}`
                        }
                    }
                }
            }
        }

        RowLayout {
            id: controlButtons
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 6
            }
            spacing: 4

            RippleButton {
                Layout.preferredHeight: 35
                Layout.preferredWidth: 90
                font.pixelSize: Appearance.font.pixelSize.larger
                buttonRadius: 0

                onClicked: {
                    TimerService.toggleStopwatch()
                }

                colBackground: TimerService.stopwatchRunning ? "#174339" : "#36ff8b"
                colBackgroundHover: TimerService.stopwatchRunning ? "#174339" : "#36ff8b"
                colRipple: TimerService.stopwatchRunning ? "#174339" : "#36ff8b"

                contentItem: StyledText {
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Appearance.font.family.monospace
                    color: TimerService.stopwatchRunning ? "#e8fff3" : "#030806"
                    text: TimerService.stopwatchRunning ? Translation.tr("Pause") : TimerService.stopwatchTime === 0 ? Translation.tr("Start") : Translation.tr("Resume")
                }
            }

            RippleButton {
                implicitHeight: 35
                implicitWidth: 90
                font.pixelSize: Appearance.font.pixelSize.larger
                buttonRadius: 0

                onClicked: {
                    if (TimerService.stopwatchRunning) 
                        TimerService.stopwatchRecordLap()
                    else 
                        TimerService.stopwatchReset()
                }
                enabled: TimerService.stopwatchTime > 0 || Persistent.states.timer.stopwatch.laps.length > 0

                colBackground: TimerService.stopwatchRunning ? "#06110e" : "#3b0f1a"
                colBackgroundHover: TimerService.stopwatchRunning ? "#06110e" : "#3b0f1a"
                colRipple: TimerService.stopwatchRunning ? "#06110e" : "#3b0f1a"

                contentItem: StyledText {
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Appearance.font.family.monospace
                    text: TimerService.stopwatchRunning ? Translation.tr("Lap") : Translation.tr("Reset")
                    color: TimerService.stopwatchRunning ? "#e8fff3" : "#ff6b8b"
                }
            }
        }
    }
}