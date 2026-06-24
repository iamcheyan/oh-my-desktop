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

WindowDialog {
    id: clipboardDialog
    backgroundHeight: 520
    backgroundWidth: 850
    anchorPosition: 0
    anchorMargin: 8
    focus: true

    onActiveFocusChanged: {
        if (!activeFocus && visible && show) {
            clipboardDialog.forceActiveFocus();
        }
    }

    property int keyboardIndex: 0
    property real wheelAccum: 0

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
            Cliphist.copy(Cliphist.entries[keyboardIndex]);
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
        }
    }

    RowLayout {
        id: layoutRow
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 16

        // Left Column: Scrollable List
        ColumnLayout {
            Layout.preferredWidth: (layoutRow.width - layoutRow.spacing * 2 - 1) / 2
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            ListView {
                id: clipboardList
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                Layout.leftMargin: 0
                Layout.rightMargin: 0

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

        // Vertical separator
        Rectangle {
            Layout.fillHeight: true
            width: 1
            color: Appearance.tiling.border
            opacity: 0.5
        }

        // Right Column: Preview
        ColumnLayout {
            Layout.preferredWidth: (layoutRow.width - layoutRow.spacing * 2 - 1) / 2
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            StyledText {
                text: qsTr("Preview")
                font.bold: true
                font.pixelSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnSurface
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Appearance.tiling.border
                opacity: 0.3
            }

            Item {
                id: previewContainer
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
                        font.family: "monospace"
                        font.pixelSize: Appearance.font.pixelSize.smallie
                        color: Appearance.colors.colOnSurface
                        background: null
                        activeFocusOnPress: false
                    }
                }

                // Empty State
                StyledText {
                    anchors.centerIn: parent
                    visible: clipboardDialog.currentEntry === ""
                    text: qsTr("No item selected")
                    color: Appearance.tiling.textDim
                }
            }
        }
    }

    WindowDialogSeparator {}

    WindowDialogToolbar {
        paginationVisible: false
        leadingActions: [
            { type: "icon", icon: "close", callback: () => clipboardDialog.dismiss() }
        ]
        trailingActions: [
            { type: "icon", icon: "delete_sweep", color: Appearance.tiling.error, callback: () => { Cliphist.wipe(); clipboardDialog.dismiss(); } }
        ]
    }
}