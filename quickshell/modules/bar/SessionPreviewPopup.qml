pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: root

    property var previewData: ({ count: 0, workspaceCount: 0, workspaces: [] })
    property string sessionCommand: "omd-session"
    signal confirmed()
    signal dismissed()

    color: "transparent"
    visible: true
    implicitWidth: 560
    implicitHeight: Math.min(620, Math.max(420, 180 + Math.min(340, workspaceColumn.implicitHeight)))

    Component.onCompleted: forceActiveFocus()

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.close();
            event.accepted = true;
        }
    }

    function close() {
        root.dismissed();
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        StyledRectangularShadow {
            target: shell
            opacity: shell.opacity
        }

        Rectangle {
            id: shell
            anchors.fill: parent
            anchors.margins: Appearance.sizes.elevationMargin + 2
            radius: TuiStyle.shellRadius
            color: TuiStyle.bg
            border.width: TuiStyle.borderWidth
            border.color: TuiStyle.menuBorder
            clip: true

            Item {
                anchors.fill: parent
                anchors.margins: 18

                RowLayout {
                    id: headerRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    Layout.fillWidth: true
                    spacing: 12

                    NerdIcon {
                        text: NerdIconMap.workspaceSnapshot
                        iconSize: 22
                        color: TuiStyle.accent
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: "Workspace Snapshot"
                            color: TuiStyle.fg
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.DemiBold
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: `${root.previewData.workspaceCount || 0} workspaces / ${root.previewData.count || 0} windows`
                            color: TuiStyle.muted
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }

                Rectangle {
                    id: headerDivider
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: headerRow.bottom
                    anchors.topMargin: 14
                    height: 1
                    color: TuiStyle.line
                    opacity: TuiStyle.dividerOpacity
                }

                RowLayout {
                    id: footerRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    spacing: 10

                    Item { Layout.fillWidth: true }

                    RippleButton {
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 42
                        buttonRadius: 10
                        colBackground: TuiStyle.surfaceRaised
                        colBackgroundHover: TuiStyle.surfaceHover
                        colRipple: TuiStyle.surfacePressed
                        onClicked: root.close()
                        contentItem: StyledText {
                            text: "Cancel"
                            color: TuiStyle.fg
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: Appearance.font.pixelSize.normal
                        }
                    }

                    RippleButton {
                        Layout.preferredWidth: 160
                        Layout.preferredHeight: 42
                        buttonRadius: 10
                        colBackground: TuiStyle.selection
                        colBackgroundHover: TuiStyle.controlHover
                        colRipple: TuiStyle.surfacePressed
                        onClicked: {
                            Quickshell.execDetached([root.sessionCommand, "save-close"]);
                            root.confirmed();
                        }
                        contentItem: StyledText {
                            text: "Confirm & Close"
                            color: TuiStyle.fg
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                        }
                    }
                }

                StyledFlickable {
                    id: previewFlickable
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: headerDivider.bottom
                    anchors.topMargin: 14
                    anchors.bottom: footerRow.top
                    anchors.bottomMargin: 18
                    clip: true
                    contentHeight: workspaceColumn.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    boundsMovement: Flickable.StopAtBounds

                    ColumnLayout {
                        id: workspaceColumn
                        width: previewFlickable.width
                        spacing: 10

                        Repeater {
                            model: root.previewData.workspaces || []
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: wsContent.implicitHeight + 18
                                radius: TuiStyle.radius
                                color: TuiStyle.surfaceRaised
                                border.width: 1
                                border.color: TuiStyle.line

                                ColumnLayout {
                                    id: wsContent
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 10
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: `Workspace ${modelData.name || modelData.id}`
                                            color: TuiStyle.fg
                                            font.pixelSize: Appearance.font.pixelSize.normal
                                            font.weight: Font.DemiBold
                                        }

                                        StyledText {
                                            text: `monitor ${modelData.monitor}`
                                            color: TuiStyle.muted
                                            font.pixelSize: Appearance.font.pixelSize.small
                                        }
                                    }

                                    Repeater {
                                        model: modelData.clients || []
                                        delegate: RowLayout {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            spacing: 8

                                            NerdIcon {
                                                text: modelData.floating ? NerdIconMap.swapHoriz : NerdIconMap.circle
                                                iconSize: 12
                                                color: modelData.floating ? TuiStyle.warning : TuiStyle.muted
                                            }

                                            StyledText {
                                                Layout.preferredWidth: 110
                                                text: modelData.class || "unknown"
                                                color: TuiStyle.fg
                                                font.pixelSize: Appearance.font.pixelSize.small
                                                elide: Text.ElideRight
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: {
                                                    const session = modelData.session;
                                                    const program = modelData.program;
                                                    const sessionText = session && session.type
                                                        ? `${session.type}:${session.name || "default"}`
                                                        : "";
                                                    const programText = program && program.name
                                                        ? `program:${program.name}`
                                                        : "";
                                                    const details = sessionText.length > 0
                                                        ? sessionText
                                                        : (programText.length > 0 ? programText : (modelData.cwd || ""));
                                                    return details.length > 0
                                                        ? `${modelData.title || ""}  ${details}`
                                                        : (modelData.title || "");
                                                }
                                                color: TuiStyle.muted
                                                font.pixelSize: Appearance.font.pixelSize.small
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
