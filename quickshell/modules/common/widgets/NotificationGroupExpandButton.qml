pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property int count
    required property bool expanded
    property real fontSize: Appearance?.font.pixelSize.small ?? 12
    property bool hovered: hoverArea.containsMouse
    signal clicked()

    implicitHeight: 24
    implicitWidth: contentRow.implicitWidth
    Layout.alignment: Qt.AlignVCenter
    Layout.fillHeight: false

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 0
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 4

        StyledText {
            visible: root.count > 1
            text: root.count
            font.pixelSize: root.fontSize
            font.family: Appearance.font.family.monospace
            color: root.hovered || root.expanded ? TuiStyle.accent : TuiStyle.dim
        }

        StyledText {
            text: root.expanded ? "-" : "+"
            font.pixelSize: root.fontSize
            font.family: Appearance.font.family.monospace
            color: root.hovered || root.expanded ? TuiStyle.accent : TuiStyle.fg
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
