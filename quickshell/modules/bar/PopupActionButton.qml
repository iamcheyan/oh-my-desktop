// PopupActionButton — standardized header action icon.
// 36×36px touch target, 22px MaterialSymbol, hover background.
// Use in popup header rows for settings gears, clear buttons, etc.
pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string icon: ""
    property string tooltip: ""
    property int iconSize: 22
    property color color: TuiStyle.muted
    property color colorHover: TuiStyle.fg

    signal clicked()

    implicitWidth: 36
    implicitHeight: 36
    opacity: enabled ? 1 : 0.38

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: root.enabled && mouseArea.containsMouse ? TuiStyle.surfaceHover : "transparent"
    }

    MaterialSymbol {
        anchors.centerIn: parent
        text: root.icon
        iconSize: root.iconSize
        color: root.enabled && mouseArea.containsMouse ? root.colorHover : root.color
    }

    StyledToolTip {
        text: root.tooltip
        extraVisibleCondition: root.enabled && root.tooltip.length > 0 && mouseArea.containsMouse
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
