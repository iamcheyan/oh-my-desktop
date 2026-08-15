pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    // Parenthesize: `!a ?? true` parses as (!a) ?? true and never applies
    // the intended "treat as password when unknown" default.
    readonly property bool usePasswordChars: !(PolkitService.flow?.responseVisible ?? true)

    Keys.onPressed: event => { // Esc to close
        if (event.key === Qt.Key_Escape) {
            PolkitService.cancel();
        }
    }

    function submit() {
        PolkitService.submit(inputField.text);
    }
    function focusInput() {
        inputField.forceActiveFocus();
        inputFocusTimer.restart();
    }

    Component.onCompleted: focusInput()

    Timer {
        id: inputFocusTimer
        interval: 80
        repeat: false
        onTriggered: inputField.forceActiveFocus()
    }

    Connections {
        target: PolkitService
        function onInteractionAvailableChanged() {
            if (!PolkitService.interactionAvailable) return;
            inputField.text = "";
            root.focusInput();
        }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        color: Appearance.colors.colScrim
        opacity: 0
        Component.onCompleted: {
            opacity = 1
        }
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    WindowDialog {
        anchors.centerIn: parent
        backgroundWidth: 450
        show: false
        Component.onCompleted: {
            show = true
            root.focusInput()
        }

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            iconSize: 26
            text: "security"
            color: Appearance.colors.colSecondary
        }

        WindowDialogTitle {
            id: titleText
            Layout.fillWidth: true
            textAlignment: Text.AlignHCenter
            text: "Authentication"
        }

        WindowDialogParagraph {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignLeft
            text: PolkitService.cleanMessage
        }

        MaterialTextField {
            id: inputField
            Layout.fillWidth: true
            focus: true
            enabled: PolkitService.interactionAvailable
            placeholderText: PolkitService.cleanPrompt
            echoMode: root.usePasswordChars ? TextInput.Password : TextInput.Normal
            onAccepted: root.submit();

            Keys.onPressed: event => { // Esc to close
                if (event.key === Qt.Key_Escape) {
                    PolkitService.cancel();
                }
            }
        }

        WindowDialogToolbar {
            Layout.bottomMargin: 10 // I honestly don't know why this is necessary
            trailingActions: [
                { type: "text", text: "Cancel", callback: () => PolkitService.cancel() },
                { type: "text", text: "OK", enabled: PolkitService.interactionAvailable, callback: () => root.submit() }
            ]
        }
    }
}
