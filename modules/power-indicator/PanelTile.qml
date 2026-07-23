import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property string icon: ""
    property string label: ""
    property color tone: TuiStyle.accent
    property bool active: false
    property bool showDivider: true
    signal clicked()

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumWidth: 0

    readonly property bool engaged: root.active || mouseArea.pressed || mouseArea.containsMouse

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: mouseArea.pressed ? TuiStyle.controlHover
            : root.active ? TuiStyle.accentWash(TuiStyle.accent)
            : mouseArea.containsMouse ? TuiStyle.controlHover
            : "transparent"

        Behavior on color {
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: parent.height * 0.55
        radius: 0.5
        color: TuiStyle.line
        opacity: 0.18
        visible: root.showDivider
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.max(0, root.width - 6)
        spacing: root.active ? 2 : 3

        NerdIcon {
            Layout.alignment: Qt.AlignHCenter
            iconSize: root.active ? 17 : 19
            text: root.icon
            color: root.active ? TuiStyle.accent
                : root.engaged ? root.tone
                : TuiStyle.dim
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.label
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: root.active ? Font.Bold : Font.DemiBold
            color: root.engaged ? TuiStyle.fg : TuiStyle.dim
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
