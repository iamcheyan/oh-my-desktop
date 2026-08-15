pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: pill
    property string label: ""
    property bool active: false
    property bool warning: false

    Layout.preferredHeight: 28
    Layout.preferredWidth: pillText.implicitWidth + 24
    radius: height / 2
    color: active ? SettingsTokens.accentSoft : warning ? SettingsTokens.warningPanel : SettingsTokens.button
    border.width: 1
    border.color: active ? SettingsTokens.accent : warning ? SettingsTokens.warningBorder : SettingsTokens.buttonBorder

    StyledText {
        id: pillText
        anchors.centerIn: parent
        text: pill.label
        color: pill.active ? SettingsTokens.accent : SettingsTokens.muted
        font.pixelSize: Appearance.font.pixelSize.smaller
        font.weight: Font.Medium
    }
}