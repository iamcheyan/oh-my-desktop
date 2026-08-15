pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property string title: ""
    property string subtitle: ""
    property bool active: false
    default property alias content: contentColumn.children
    signal back()

    anchors.fill: parent
    visible: root.active

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: SettingsTokens.radius
                color: backMouse.containsMouse ? SettingsTokens.buttonHover : "transparent"

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    iconSize: 20
                    color: SettingsTokens.fg
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.back()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: root.title
                    color: SettingsTokens.fg
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                StyledText {
                    visible: root.subtitle.length > 0
                    Layout.fillWidth: true
                    text: root.subtitle
                    color: SettingsTokens.muted
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideRight
                }
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: contentColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: contentColumn
                width: parent.width
                spacing: 8
            }
        }
    }
}
