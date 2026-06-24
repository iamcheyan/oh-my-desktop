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

    readonly property bool selected: ListView.isCurrentItem
    readonly property bool activeNetwork: wifiNetwork?.active ?? false
    readonly property bool pending: Network.wifiConnectTarget === wifiNetwork
    readonly property bool passwordOpen: wifiNetwork?.askingPassword ?? false
    property bool hovered: false

    signal dismiss()

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

    implicitWidth: ListView.view?.width ?? 520
    implicitHeight: passwordOpen ? 112 : 34
    color: selected ? Appearance.tiling.bgActive
        : hovered ? Appearance.tiling.bgHover
        : "transparent"
    border.width: selected ? Appearance.tiling.borderWidth : 0
    border.color: activeNetwork ? Appearance.tiling.success : Appearance.tiling.borderFocus
    clip: true

    Behavior on implicitHeight {
        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onClicked: {
            root.ListView.view.currentIndex = root.index;
            Network.connectToWifiNetwork(root.wifiNetwork);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 5
        anchors.bottomMargin: 5
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            spacing: 8

            StyledText {
                Layout.preferredWidth: 16
                horizontalAlignment: Text.AlignHCenter
                text: root.activeNetwork ? "●" : root.pending ? "…" : root.selected ? ">" : " "
                color: root.activeNetwork ? Appearance.tiling.success
                    : root.pending ? Appearance.tiling.accentBright
                    : root.selected ? Appearance.tiling.textBright
                    : Appearance.tiling.textDim
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {
                Layout.fillWidth: true
                text: root.wifiNetwork?.ssid ?? Translation.tr("Unknown")
                elide: Text.ElideRight
                color: root.activeNetwork || root.selected ? Appearance.tiling.textBright : Appearance.tiling.text
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
                textFormat: Text.PlainText
            }

            StyledText {
                Layout.preferredWidth: 54
                horizontalAlignment: Text.AlignRight
                text: root.signalBars(root.wifiNetwork?.strength ?? 0)
                color: (root.wifiNetwork?.strength ?? 0) > 45 ? Appearance.tiling.success : Appearance.tiling.textDim
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {
                Layout.preferredWidth: 34
                horizontalAlignment: Text.AlignRight
                text: `${root.wifiNetwork?.strength ?? 0}%`
                color: Appearance.tiling.textDim
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignRight
                text: root.frequencyBand(root.wifiNetwork?.frequency ?? 0)
                color: Appearance.tiling.textDim
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {
                Layout.preferredWidth: 72
                horizontalAlignment: Text.AlignRight
                text: root.securityLabel(root.wifiNetwork?.security)
                elide: Text.ElideRight
                color: (root.wifiNetwork?.isSecure ?? false) ? Appearance.tiling.accentBright : Appearance.tiling.textDim
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }

        Rectangle {
            visible: root.passwordOpen
            Layout.fillWidth: true
            Layout.preferredHeight: 66
            color: Appearance.tiling.bgInput
            border.width: Appearance.tiling.borderWidth
            border.color: Appearance.tiling.borderFocus

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                StyledText {
                    text: "password:"
                    color: Appearance.tiling.textDim
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    color: Appearance.tiling.bg
                    border.width: Appearance.tiling.borderWidth
                    border.color: passwordField.activeFocus ? Appearance.tiling.accentBright : Appearance.tiling.border

                    TextInput {
                        id: passwordField
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        color: Appearance.tiling.textBright
                        selectionColor: Appearance.tiling.accent
                        selectedTextColor: Appearance.tiling.bg
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.small
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData
                        focus: root.passwordOpen
                        onAccepted: Network.changePassword(root.wifiNetwork, text)
                    }
                }

                DialogButton {
                    buttonText: Translation.tr("Cancel")
                    implicitWidth: 78
                    onClicked: root.wifiNetwork.askingPassword = false
                }

                DialogButton {
                    buttonText: Translation.tr("Connect")
                    implicitWidth: 86
                    colBackgroundHover: Appearance.tiling.bgHover
                    colText: Appearance.tiling.textBright
                    onClicked: Network.changePassword(root.wifiNetwork, passwordField.text)
                }
            }
        }

        Rectangle {
            visible: (root.wifiNetwork?.active && (root.wifiNetwork?.security ?? "").trim().length === 0) ?? false
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: "transparent"

            DialogButton {
                anchors.right: parent.right
                implicitHeight: 26
                buttonText: Translation.tr("Open captive portal")
                colBackground: Appearance.tiling.bgActive
                colBackgroundHover: Appearance.tiling.bgHover
                colRipple: Appearance.tiling.bgActive
                onClicked: Network.openPublicWifiPortal()
            }
        }
    }
}
