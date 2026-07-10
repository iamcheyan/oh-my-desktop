import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: row
    property string iconName: ""
    property string label: ""
    property string description: ""
    property string value: ""
    property color valueColor: SettingsTokens.muted
    property bool showChevron: false
    property int rightInset: 12
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: 56
    radius: SettingsTokens.radius
    color: rowMouse.containsMouse ? SettingsTokens.cardHover : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: row.rightInset
        spacing: 14

        MaterialSymbol {
            visible: row.iconName.length > 0
            Layout.preferredWidth: visible ? 22 : 0
            Layout.fillHeight: true
            text: row.iconName
            iconSize: 18
            color: SettingsTokens.muted
        }

        ColumnLayout {
            id: rowText
            Layout.fillWidth: true
            spacing: 3

            StyledText {
                Layout.fillWidth: true
                text: row.label
                color: SettingsTokens.fg
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
            }

            StyledText {
                visible: row.description.length > 0
                Layout.fillWidth: true
                text: row.description
                color: SettingsTokens.dim
                font.pixelSize: Appearance.font.pixelSize.smaller
                elide: Text.ElideRight
            }
        }

        StyledText {
            id: valueText
            visible: row.value.length > 0
            Layout.preferredWidth: visible ? Math.min(180, implicitWidth) : 0
            Layout.fillHeight: true
            text: row.value
            color: row.valueColor
            font.pixelSize: Appearance.font.pixelSize.small
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        MaterialSymbol {
            visible: row.showChevron
            Layout.preferredWidth: visible ? 20 : 0
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
        cursorShape: row.showChevron ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: row.clicked()
    }
}