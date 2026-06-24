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
    property color selectionColor: "#687bad"
    property color foregroundColor: "#f8f8f2"
    property color dimColor: "#8a8a8a"
    property color greenColor: "#32ff6a"
    property color blueColor: "#8ec7ff"
    property color bgColor: "#000000"

    readonly property bool selected: ListView.isCurrentItem
    readonly property bool activeNetwork: wifiNetwork?.active ?? false
    readonly property bool pending: Network.wifiConnectTarget === wifiNetwork
    readonly property bool passwordOpen: wifiNetwork?.askingPassword ?? false

    function signalBars(strength) {
        if (strength > 80) return "▇▇▇▇";
        if (strength > 60) return "▇▇▇▁";
        if (strength > 40) return "▇▇▁▁";
        if (strength > 20) return "▇▁▁▁";
        return "▁▁▁▁";
    }

    function frequencyBand(frequency) {
        if (frequency >= 5900) return "6G";
        if (frequency >= 4900) return "5G";
        if (frequency > 0) return "2G";
        return "--";
    }

    function securityLabel(security) {
        const value = (security ?? "").trim();
        return value.length > 0 ? value : "OPEN";
    }

    implicitWidth: ListView.view?.width ?? 680
    implicitHeight: passwordOpen ? 100 : 34
    color: selected ? selectionColor : "transparent"
    clip: true

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.ListView.view.currentIndex = root.index;
            Network.connectToWifiNetwork(root.wifiNetwork);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            spacing: 8

            TuiCell {
                Layout.preferredWidth: 28
                text: root.activeNetwork ? "●" : root.pending ? "…" : " "
                color: root.selected ? root.foregroundColor : root.greenColor
                horizontalAlignment: Text.AlignHCenter
            }

            TuiCell {
                Layout.preferredWidth: 220
                text: root.wifiNetwork?.ssid ?? Translation.tr("Unknown")
                elide: Text.ElideRight
                color: root.selected || root.activeNetwork ? root.foregroundColor : Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.78)
            }

            TuiCell {
                Layout.preferredWidth: 88
                text: root.signalBars(root.wifiNetwork?.strength ?? 0)
                color: root.selected ? root.foregroundColor : root.greenColor
                horizontalAlignment: Text.AlignHCenter
            }

            TuiCell {
                Layout.preferredWidth: 64
                text: `${root.wifiNetwork?.strength ?? 0}%`
                color: root.selected ? root.foregroundColor : root.dimColor
                horizontalAlignment: Text.AlignHCenter
            }

            TuiCell {
                Layout.preferredWidth: 64
                text: root.frequencyBand(root.wifiNetwork?.frequency ?? 0)
                color: root.selected ? root.foregroundColor : root.dimColor
                horizontalAlignment: Text.AlignHCenter
            }

            TuiCell {
                Layout.fillWidth: true
                text: root.securityLabel(root.wifiNetwork?.security)
                elide: Text.ElideRight
                color: root.selected ? root.foregroundColor
                    : (root.wifiNetwork?.isSecure ?? false) ? root.blueColor
                    : root.dimColor
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Rectangle {
            visible: root.passwordOpen
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: root.bgColor
            border.width: 1
            border.color: root.greenColor

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                TuiCell {
                    text: "Password"
                    color: root.dimColor
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    color: "#050505"
                    border.width: 1
                    border.color: passwordField.activeFocus ? root.greenColor : root.dimColor

                    TextInput {
                        id: passwordField
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.foregroundColor
                        selectionColor: root.selectionColor
                        selectedTextColor: root.foregroundColor
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.small
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData
                        focus: root.passwordOpen
                        onAccepted: Network.changePassword(root.wifiNetwork, text)
                    }
                }

                TuiAction {
                    label: "Cancel"
                    onClicked: root.wifiNetwork.askingPassword = false
                }

                TuiAction {
                    label: "Connect"
                    onClicked: Network.changePassword(root.wifiNetwork, passwordField.text)
                }
            }
        }
    }

    component TuiCell: StyledText {
        color: root.foregroundColor
        font.family: Appearance.font.family.monospace
        font.pixelSize: Appearance.font.pixelSize.small
        textFormat: Text.PlainText
        verticalAlignment: Text.AlignVCenter
    }

    component TuiAction: Rectangle {
        id: action

        property string label: ""
        signal clicked()

        Layout.preferredWidth: actionText.implicitWidth + 18
        Layout.preferredHeight: 28
        color: actionMouse.containsMouse ? root.selectionColor : root.bgColor
        border.width: 1
        border.color: root.dimColor

        TuiCell {
            id: actionText
            anchors.centerIn: parent
            text: action.label
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: action.clicked()
        }
    }
}
