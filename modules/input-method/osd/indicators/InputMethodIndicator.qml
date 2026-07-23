import qs.services as Services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property string selectedSchema: Services.InputMethod.pendingSchema || Services.InputMethod.schema

    implicitWidth: 360 + Appearance.sizes.elevationMargin * 2
    implicitHeight: popupBg.implicitHeight + Appearance.sizes.elevationMargin * 2

    StyledRectangularShadow {
        target: popupBg
    }

    Rectangle {
        id: popupBg
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        implicitWidth: 360
        implicitHeight: contentColumn.implicitHeight + 24
        color: TuiStyle.bg
        radius: TuiStyle.radius
        border.width: TuiStyle.borderWidth
        border.color: TuiStyle.menuBorder
        clip: true

        ColumnLayout {
            id: contentColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 12
            }
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                Layout.bottomMargin: 8
                spacing: 10

                NerdIcon {
                    text: NerdIconMap.keyboard
                    iconSize: 20
                    color: TuiStyle.accent
                }

                StyledText {
                    Layout.fillWidth: true
                    text: "Input language"
                    color: TuiStyle.fg
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                }

                StyledText {
                    text: "Win + Space"
                    color: TuiStyle.dim
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: TuiStyle.line
                opacity: TuiStyle.dividerOpacity
            }

            Repeater {
                model: Services.InputMethod.schemas

                delegate: Rectangle {
                    id: schemaRow
                    required property var modelData
                    readonly property bool selected: modelData.id === root.selectedSchema

                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    radius: TuiStyle.miniRadius
                    color: selected ? TuiStyle.selection : "transparent"

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        height: 30
                        radius: TuiStyle.miniRadius
                        color: schemaRow.selected ? TuiStyle.accent : TuiStyle.surfaceSubtle

                        StyledText {
                            anchors.centerIn: parent
                            text: schemaRow.modelData.badge
                            color: schemaRow.selected ? TuiStyle.bg : TuiStyle.fg
                            font.family: Appearance.font.family.main
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 50
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        StyledText {
                            text: schemaRow.modelData.title
                            color: TuiStyle.fg
                            font.family: Appearance.font.family.main
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: schemaRow.selected ? Font.DemiBold : Font.Normal
                        }

                        StyledText {
                            text: schemaRow.modelData.variant
                            color: TuiStyle.dim
                            font.family: Appearance.font.family.main
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                    }

                    NerdIcon {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: NerdIconMap.check
                        iconSize: 15
                        color: TuiStyle.accent
                        visible: schemaRow.selected
                    }
                }
            }
        }
    }
}
