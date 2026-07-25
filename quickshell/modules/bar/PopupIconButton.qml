// PopupIconButton — individual icon button for IconActionRow.
// Modern dark popup style with soft borders, surface bg, and accent hover feedback.
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
    property color hoverAccent: accent
    property color hoverColor: Qt.rgba(1, 1, 1, 0.08)
    property bool enabledState: true
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: 56
    opacity: iconBtn.enabledState ? 1.0 : 0.38

    readonly property bool isHovered: iconBtnMouse.containsMouse && iconBtn.enabledState

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: iconBtn.isHovered ? iconBtn.hoverColor : Qt.rgba(1, 1, 1, 0.04)
        border.width: 1
        border.color: iconBtn.isHovered 
            ? (iconBtn.hoverAccent !== TuiStyle.fg ? Qt.rgba(iconBtn.hoverAccent.r, iconBtn.hoverAccent.g, iconBtn.hoverAccent.b, 0.4) : Qt.rgba(1, 1, 1, 0.15))
            : Qt.rgba(1, 1, 1, 0.06)

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 3

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: iconBtn.icon
                iconSize: 20
                color: iconBtn.isHovered ? iconBtn.hoverAccent : iconBtn.accent

                Behavior on color { ColorAnimation { duration: 150 } }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: iconBtn.label
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
                color: iconBtn.isHovered ? TuiStyle.fg : TuiStyle.dim
                horizontalAlignment: Text.AlignHCenter

                Behavior on color { ColorAnimation { duration: 150 } }
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

