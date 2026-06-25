import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.common.functions
import Quickshell
import Quickshell.Io
import QtQuick.Controls

Rectangle {
    id: clipboardDialog
    property bool show: false
    signal dismiss()

    width: 800
    height: 480
    color: "#1a1a1a"
    border.color: "#444444"
    border.width: 2
    radius: 0
    focus: true

    onActiveFocusChanged: {
        if (!activeFocus && visible && show) {
            clipboardDialog.forceActiveFocus();
        }
    }

    property int keyboardIndex: 0
    property real wheelAccum: 0
    property string monoFont: "JetBrainsMono Nerd Font, monospace"
    property color bgColor: "#1a1a1a"
    property color borderColor: "#444444"
    property color selectedBg: "#2a4a6a"
    property color textColor: "#c5c8c6"
    property color dimColor: "#666666"
    property color accentColor: "#4c7899"

    readonly property string currentEntry: (keyboardIndex >= 0 && keyboardIndex < Cliphist.entries.length) ? Cliphist.entries[keyboardIndex] : ""

    function loadCurrentPreview() {
        if (currentEntry && !Cliphist.entryIsImage(currentEntry)) {
            textDecoder.running = false;
            textDecoder.command = ["bash", "-c", `printf '${StringUtils.shellSingleQuoteEscape(currentEntry)}' | ${Cliphist.cliphistBinary} decode`];
            textDecoder.running = true;
        } else {
            textDecoder.running = false;
            textDecoder.decodedText = "";
        }
    }

    onCurrentEntryChanged: {
        loadCurrentPreview();
    }

    Component.onCompleted: {
        loadCurrentPreview();
    }

    Process {
        id: textDecoder
        property string decodedText: ""
        stdout: StdioCollector {
            onStreamFinished: {
                textDecoder.decodedText = text;
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            keyboardIndex = 0;
            clipboardDialog.forceActiveFocus();
            Cliphist.refresh();
            loadCurrentPreview();
        }
    }

    Connections {
        target: Cliphist
        function onEntriesChanged() {
            if (keyboardIndex >= Cliphist.entries.length) {
                keyboardIndex = Math.max(0, Cliphist.entries.length - 1);
            }
        }
    }

    function copySelected() {
        if (keyboardIndex >= 0 && keyboardIndex < Cliphist.entries.length) {
            Cliphist.paste(Cliphist.entries[keyboardIndex]);
            clipboardDialog.dismiss();
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Down) {
            event.accepted = true;
            if (Cliphist.entries.length === 0) return;
            if (keyboardIndex < Cliphist.entries.length - 1) {
                keyboardIndex++;
            }
        } else if (event.key === Qt.Key_Up) {
            event.accepted = true;
            if (keyboardIndex > 0) {
                keyboardIndex--;
            }
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = true;
            copySelected();
        } else if (event.key === Qt.Key_Escape) {
            event.accepted = true;
            clipboardDialog.dismiss();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        // Title bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: "#222222"
            border.color: borderColor
            border.width: 1

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: " CLIPBOARD "
                font.family: monoFont
                font.pixelSize: 13
                font.bold: true
                color: accentColor
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "[ESC] close  [Enter] paste  [↑↓] navigate"
                font.family: monoFont
                font.pixelSize: 11
                color: dimColor
            }
        }

        // Main content area
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Left panel - List
            Rectangle {
                Layout.preferredWidth: 380
                Layout.fillHeight: true
                color: bgColor
                border.color: borderColor
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 1
                    spacing: 0

                    // List header
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        color: "#222222"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: " History"
                            font.family: monoFont
                            font.pixelSize: 12
                            color: dimColor
                        }
                    }

                    // List content
                    ListView {
                        id: clipboardList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 0
                        boundsBehavior: Flickable.StopAtBounds
                        boundsMovement: Flickable.StopAtBounds
                        highlightMoveDuration: 100
                        highlightResizeDuration: 0
                        interactive: true

                        model: ScriptModel {
                            values: Cliphist.entries
                        }

                        delegate: ClipboardItem {
                            required property string modelData
                            required property int index
                            entry: modelData
                            width: ListView.view.width
                            selected: clipboardDialog.keyboardIndex === index
                            onItemClicked: clipboardDialog.dismiss()
                            onHoveredChanged: {
                                if (hovered) {
                                    clipboardDialog.keyboardIndex = index;
                                }
                            }
                        }

                        Connections {
                            target: clipboardDialog
                            function onKeyboardIndexChanged() {
                                if (clipboardDialog.keyboardIndex >= 0 && clipboardDialog.keyboardIndex < clipboardList.count) {
                                    clipboardList.positionViewAtIndex(clipboardDialog.keyboardIndex, ListView.Contain);
                                }
                            }
                        }
                    }
                }
            }

            // Right panel - Preview
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: bgColor
                border.color: borderColor
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 1
                    spacing: 0

                    // Preview header
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        color: "#222222"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: " Preview"
                            font.family: monoFont
                            font.pixelSize: 12
                            color: dimColor
                        }
                    }

                    // Preview content
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        // Image Preview
                        CliphistImage {
                            anchors.centerIn: parent
                            visible: clipboardDialog.currentEntry !== "" && Cliphist.entryIsImage(clipboardDialog.currentEntry)
                            entry: visible ? clipboardDialog.currentEntry : ""
                            maxWidth: parent.width - 20
                            maxHeight: parent.height - 20
                        }

                        // Text Preview
                        ScrollView {
                            anchors.fill: parent
                            visible: clipboardDialog.currentEntry !== "" && !Cliphist.entryIsImage(clipboardDialog.currentEntry)
                            clip: true

                            TextArea {
                                readOnly: true
                                selectByMouse: true
                                wrapMode: TextEdit.Wrap
                                text: textDecoder.decodedText
                                font.family: monoFont
                                font.pixelSize: 13
                                color: textColor
                                background: Rectangle {
                                    color: bgColor
                                }
                                activeFocusOnPress: false
                                padding: 8
                            }
                        }

                        // Empty State
                        Text {
                            anchors.centerIn: parent
                            visible: clipboardDialog.currentEntry === ""
                            text: "No item selected"
                            font.family: monoFont
                            font.pixelSize: 13
                            color: dimColor
                        }
                    }
                }
            }
        }

        // Status bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            color: "#222222"
            border.color: borderColor
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 16

                Text {
                    text: Cliphist.entries.length + " items"
                    font.family: monoFont
                    font.pixelSize: 11
                    color: dimColor
                }

                Text {
                    text: clipboardDialog.keyboardIndex >= 0 ? (clipboardDialog.keyboardIndex + 1) + "/" + Cliphist.entries.length : "-/-"
                    font.family: monoFont
                    font.pixelSize: 11
                    color: dimColor
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "cliphist"
                    font.family: monoFont
                    font.pixelSize: 11
                    color: dimColor
                }
            }
        }
    }
}
