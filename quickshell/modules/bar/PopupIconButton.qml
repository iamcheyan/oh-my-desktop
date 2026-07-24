// PopupIconButton — individual icon button for IconActionRow.
// Dark popup style: transparent bg, TuiStyle hover, thin border.
import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: iconBtn
    property string icon: ""
    property string label: ""
    property color accent: TuiStyle.fg
    property bool enabledState: true
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: 56
    opacity: iconBtn.enabledState ? 1.0 : 0.38

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: iconBtnMouse.containsMouse && iconBtn.enabledState
            ? TuiStyle.controlHover : "transparent"
        border.width: 1
        border.color: TuiStyle.panelAlt

        Behavior on color { ColorAnimation { duration: 100 } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: iconBtn.icon
                iconSize: 18
                color: iconBtn.accent
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: iconBtn.label
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
                color: TuiStyle.dim
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    MouseArea {
        id: iconBtnMouse
        anchors.fill: parent
        enabled: iconBtn.enabledState
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: iconBtn.clicked()
    }
}
