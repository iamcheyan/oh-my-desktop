import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property string iconName: ""
    property string label: ""
    property string description: ""
    property string value: ""
    property color valueColor: SettingsTokens.muted
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: 56
    radius: SettingsTokens.radius
    color: rowMouse.containsMouse ? SettingsTokens.cardHover : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 14

        MaterialSymbol {
            visible: root.iconName.length > 0
            Layout.preferredWidth: visible ? 22 : 0
            Layout.fillHeight: true
            text: root.iconName
            iconSize: 18
            color: SettingsTokens.muted
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            StyledText {
                Layout.fillWidth: true
                text: root.label
                color: SettingsTokens.fg
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
            }

            StyledText {
                visible: root.description.length > 0
                Layout.fillWidth: true
                text: root.description
                color: SettingsTokens.dim
                font.pixelSize: Appearance.font.pixelSize.smaller
                elide: Text.ElideRight
            }
        }

        StyledText {
            visible: root.value.length > 0
            Layout.preferredWidth: visible ? Math.min(180, implicitWidth) : 0
            Layout.fillHeight: true
            text: root.value
            color: root.valueColor
            font.pixelSize: Appearance.font.pixelSize.small
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        MaterialSymbol {
            Layout.preferredWidth: 20
            Layout.fillHeight: true
            text: "chevron_right"
            iconSize: 18
            color: SettingsTokens.muted
        }
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
