pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

StyledText {
    property int topInset: 6
    property int bottomInset: 2

    Layout.fillWidth: true
    Layout.topMargin: topInset
    Layout.bottomMargin: bottomInset
    font.family: Appearance.font.family.monospace
    font.pixelSize: Appearance.font.pixelSize.smaller
    font.weight: Font.Bold
    color: TuiStyle.dim
}
