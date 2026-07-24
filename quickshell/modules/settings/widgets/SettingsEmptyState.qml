import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    property string iconName: ""
    property string title: ""
    property string description: ""

    Layout.fillWidth: true
    Layout.alignment: Qt.AlignCenter
    spacing: 8

    Item { Layout.fillHeight: true; Layout.preferredHeight: 24 }

    MaterialSymbol {
        visible: root.iconName.length > 0
        Layout.alignment: Qt.AlignHCenter
        text: root.iconName
        iconSize: 40
        color: SettingsTokens.muted
    }

    StyledText {
        visible: root.title.length > 0
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: root.title
        color: SettingsTokens.fg
        font.pixelSize: Appearance.font.pixelSize.normal
        font.weight: Font.DemiBold
    }

    StyledText {
        visible: root.description.length > 0
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: root.description
        color: SettingsTokens.muted
        font.pixelSize: Appearance.font.pixelSize.small
        wrapMode: Text.WordWrap
    }

    Item { Layout.fillHeight: true; Layout.preferredHeight: 24 }
}
