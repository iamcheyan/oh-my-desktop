import qs.modules.common.widgets
import qs.modules.common
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    property string text: ""
    property string icon
    property alias value: spinBoxWidget.value
    property alias stepSize: spinBoxWidget.stepSize
    property alias from: spinBoxWidget.from
    property alias to: spinBoxWidget.to
    spacing: 8
    Layout.leftMargin: 8
    Layout.rightMargin: 8
    Layout.topMargin: 3
    Layout.bottomMargin: 3

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        OptionalMaterialSymbol {
            icon: root.icon
            opacity: root.enabled ? 1 : 0.4
            color: Appearance.tiling.textDim
        }
        StyledText {
            id: labelWidget
            Layout.fillWidth: true
            text: root.text
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.tiling.text
            opacity: root.enabled ? 1 : 0.4
        }
    }

    StyledSpinBox {
        id: spinBoxWidget
        Layout.fillWidth: false
        value: root.value
    }
}
