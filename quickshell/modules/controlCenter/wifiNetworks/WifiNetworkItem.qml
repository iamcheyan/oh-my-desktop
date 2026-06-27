import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.services.network
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property WifiAccessPoint wifiNetwork
    required property int index
    property color selectionColor: "#133a35"
    property color foregroundColor: TuiStyle.fg
    property color dimColor: "#66756f"
    property color greenColor: TuiStyle.green
    property color yellowColor: TuiStyle.yellow
    property color blueColor: TuiStyle.blue
    property color bgColor: TuiStyle.bg
    property color lineColor: "#12332c"

    signal activated(var network)

    readonly property bool selected: ListView.isCurrentItem
    readonly property bool activeNetwork: wifiNetwork?.active ?? false
    readonly property bool pending: Network.wifiConnectTarget === wifiNetwork

    function signalBars(strength) {
        if (strength > 84) return "████";
        if (strength > 64) return "███░";
        if (strength > 44) return "██░░";
        if (strength > 24) return "█░░░";
        return "░░░░";
    }

    function frequencyBand(frequency) {
        if (frequency >= 5900) return "6G";
        if (frequency >= 4900) return "5G";
        if (frequency > 0) return "2G";
        return "--";
    }

    function securityLabel(security) {
        const value = (security ?? "").trim();
        return value.length > 0 ? value.split(" ")[0].toUpperCase() : "OPEN";
    }

    implicitWidth: ListView.view?.width ?? 460
    implicitHeight: 38
    color: root.selected ? root.selectionColor : root.activeNetwork ? Qt.rgba(root.greenColor.r, root.greenColor.g, root.greenColor.b, 0.08) : "transparent"
    border.width: root.selected ? 1 : 0
    border.color: root.selected ? root.greenColor : "transparent"
    clip: true

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.ListView.view.currentIndex = root.index;
            root.activated(root.wifiNetwork);
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 8

        TuiCell {
            Layout.preferredWidth: 22
            text: root.pending ? ">" : root.activeNetwork ? "*" : root.selected ? ":" : " "
            color: root.pending ? root.yellowColor : root.activeNetwork ? root.greenColor : root.dimColor
            horizontalAlignment: Text.AlignHCenter
        }

        TuiCell {
            Layout.fillWidth: true
            text: root.wifiNetwork?.ssid ?? Translation.tr("Unknown")
            elide: Text.ElideRight
            color: root.selected || root.activeNetwork ? root.foregroundColor : Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.78)
        }

        TuiCell {
            Layout.preferredWidth: 64
            text: root.signalBars(root.wifiNetwork?.strength ?? 0)
            color: root.selected ? root.foregroundColor : root.greenColor
            horizontalAlignment: Text.AlignHCenter
        }

        TuiCell {
            Layout.preferredWidth: 42
            text: `${root.wifiNetwork?.strength ?? 0}`
            color: root.selected ? root.foregroundColor : root.dimColor
            horizontalAlignment: Text.AlignRight
        }

        TuiCell {
            Layout.preferredWidth: 38
            text: root.frequencyBand(root.wifiNetwork?.frequency ?? 0)
            color: root.selected ? root.foregroundColor : root.blueColor
            horizontalAlignment: Text.AlignHCenter
        }

        TuiCell {
            Layout.preferredWidth: 72
            text: root.securityLabel(root.wifiNetwork?.security)
            elide: Text.ElideRight
            color: root.selected ? root.foregroundColor : (root.wifiNetwork?.isSecure ?? false) ? root.yellowColor : root.dimColor
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
