import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property var device
    required property int index
    property color selectionColor: "#123a32"
    property color foregroundColor: "#e8fff3"
    property color dimColor: "#65736e"
    property color greenColor: "#36ff8b"
    property color yellowColor: "#e8ff82"
    property color blueColor: "#7bc7ff"
    property color lineColor: "#174339"

    signal activated(var device)

    readonly property bool selected: ListView.isCurrentItem
    readonly property bool connected: device?.connected ?? false
    readonly property bool paired: device?.paired ?? false

    function batteryLabel() {
        if (!(root.device?.batteryAvailable ?? false))
            return "--";
        return `${Math.round((root.device?.battery ?? 0) * 100)}%`;
    }

    function stateLabel() {
        if (root.connected)
            return "LINKED";
        if (root.paired)
            return "PAIRED";
        return "NEW";
    }

    implicitWidth: ListView.view?.width ?? 520
    implicitHeight: 38
    color: root.selected ? root.selectionColor : root.connected ? Qt.rgba(root.greenColor.r, root.greenColor.g, root.greenColor.b, 0.08) : "transparent"
    border.width: root.selected ? 1 : 0
    border.color: root.selected ? root.greenColor : "transparent"
    clip: true

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.ListView.view.currentIndex = root.index;
            root.activated(root.device);
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 8

        TuiCell {
            Layout.preferredWidth: 22
            text: root.connected ? "*" : root.selected ? ":" : " "
            color: root.connected ? root.greenColor : root.dimColor
            horizontalAlignment: Text.AlignHCenter
        }

        CosmicIcon {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            iconSize: 18
            name: Icons.getBluetoothDeviceCosmicIcon(root.device?.icon || "")
            color: root.selected ? root.foregroundColor : root.blueColor
        }

        TuiCell {
            Layout.fillWidth: true
            text: root.device?.name || Translation.tr("Unknown device")
            elide: Text.ElideRight
            color: root.selected || root.connected ? root.foregroundColor : Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.78)
        }

        TuiCell {
            Layout.preferredWidth: 64
            text: root.batteryLabel()
            color: root.selected ? root.foregroundColor : (root.device?.batteryAvailable ?? false) ? root.yellowColor : root.dimColor
            horizontalAlignment: Text.AlignRight
        }

        TuiCell {
            Layout.preferredWidth: 72
            text: root.paired ? "YES" : "NO"
            color: root.selected ? root.foregroundColor : root.paired ? root.blueColor : root.dimColor
            horizontalAlignment: Text.AlignHCenter
        }

        TuiCell {
            Layout.preferredWidth: 76
            text: root.stateLabel()
            color: root.selected ? root.foregroundColor : root.connected ? root.greenColor : root.paired ? root.blueColor : root.dimColor
            horizontalAlignment: Text.AlignRight
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: root.lineColor
        opacity: root.selected ? 0 : 0.55
    }

    component TuiCell: StyledText {
        color: root.foregroundColor
        font.family: Appearance.font.family.monospace
        font.pixelSize: Appearance.font.pixelSize.small
        textFormat: Text.PlainText
        verticalAlignment: Text.AlignVCenter
    }
}
