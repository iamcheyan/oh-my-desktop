import qs.modules.common
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string label: "PASSWORD"
    property alias text: input.text
    property string placeholderText: ""
    property bool revealable: true
    property bool revealed: false
    property color backgroundColor: TuiStyle.controlMuted
    property color textColor: TuiStyle.fg
    property color dimColor: TuiStyle.dim
    property color selectionColor: TuiStyle.selection
    signal accepted()

    function focusInput() {
        input.forceActiveFocus();
    }

    Layout.fillWidth: true
    Layout.preferredHeight: 42
    implicitHeight: 42
    color: backgroundColor
    radius: TuiStyle.radius
    border.width: 0

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 8
        spacing: 10

        StyledText {
            visible: root.label.length > 0
            text: root.label
            color: root.dimColor
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
        }

        TextInput {
            id: input

            Layout.fillWidth: true
            color: root.textColor
            selectionColor: root.selectionColor
            selectedTextColor: root.textColor
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.small
            echoMode: root.revealed ? TextInput.Normal : TextInput.Password
            inputMethodHints: root.revealed ? Qt.ImhNone : Qt.ImhSensitiveData
            onAccepted: root.accepted()

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.placeholderText
                color: root.dimColor
                visible: !input.text && !input.activeFocus
                font: input.font
            }
        }

        RippleButton {
            id: revealButton

            visible: root.revealable
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            buttonRadius: 6
            colBackground: hovered ? TuiStyle.surfaceHover : "transparent"
            colBackgroundHover: TuiStyle.surfaceHover
            colRipple: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.12)
            onClicked: {
                root.revealed = !root.revealed;
                input.forceActiveFocus();
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: root.revealed ? "visibility_off" : "visibility"
                iconSize: 20
                color: revealButton.hovered ? root.textColor : root.dimColor
            }
        }
    }
}
