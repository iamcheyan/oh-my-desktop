import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root
    property string title
    property string icon: ""
    default property alias contentData: sectionContent.data

    Layout.fillWidth: true
    implicitWidth: contentColumn.implicitWidth
    implicitHeight: contentColumn.implicitHeight
    radius: 0
    color: TuiStyle.bg
    border.width: TuiStyle.borderWidth
    border.color: TuiStyle.line

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 44
            radius: 0
            color: "#181818"

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 8
                    rightMargin: 8
                }
                spacing: 6

                StyledText {
                    visible: root.icon.length > 0
                    text: root.icon
                    font.family: Appearance.font.family.iconMaterial
                    font.pixelSize: Appearance.font.pixelSize.large
                    color: TuiStyle.dim
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.title
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: TuiStyle.fg
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: 1
                color: TuiStyle.line
            }
        }

        ColumnLayout {
            id: sectionContent
            Layout.fillWidth: true
            spacing: 0
        }
    }
}
