import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    property string title: ""
    default property alias content: contentColumn.children

    Layout.fillWidth: true
    spacing: 4

    StyledText {
        visible: root.title.length > 0
        Layout.fillWidth: true
        Layout.topMargin: 8
        Layout.bottomMargin: 4
        Layout.leftMargin: 4
        text: root.title
        color: SettingsTokens.muted
        font.pixelSize: Appearance.font.pixelSize.smaller
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    ColumnLayout {
        id: contentColumn
        Layout.fillWidth: true
        spacing: 2
    }
}
