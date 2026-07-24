pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.widgets

Scope {
    id: root

    required property var displayState

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: identifyWindow

            required property var modelData
            readonly property var output: root.displayState.outputByName(modelData.name)
            readonly property var size: output ? root.displayState.physicalSize(output) : ({ w: modelData.width, h: modelData.height })

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            WlrLayershell.namespace: "omd:monitor-identify"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            mask: Region {}

            Item {
                anchors.fill: parent
                opacity: 0

                Component.onCompleted: opacity = 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: TuiStyle.accent
                    border.width: 4
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: identifyLabel.implicitWidth + 40
                    height: identifyLabel.implicitHeight + 20
                    color: TuiStyle.accent
                    bottomLeftRadius: TuiStyle.miniRadius
                    bottomRightRadius: TuiStyle.miniRadius

                    StyledText {
                        id: identifyLabel
                        anchors.centerIn: parent
                        text: {
                            const name = identifyWindow.output
                                ? root.displayState.displayName(identifyWindow.output)
                                : identifyWindow.modelData.name;
                            const connector = identifyWindow.modelData.name;
                            const resolution = `${identifyWindow.size.w} x ${identifyWindow.size.h}`;
                            return name === connector
                                ? `${connector}  ·  ${resolution}`
                                : `${name}  (${connector})  ·  ${resolution}`;
                        }
                        color: TuiStyle.bg
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }
}
