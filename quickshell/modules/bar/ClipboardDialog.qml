import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: clipboardDialog

    property bool show: false
    signal dismiss()

    width: 1000
    height: 640
    color: TuiStyle.bg
    border.color: TuiStyle.line
    border.width: TuiStyle.borderWidth
    radius: 0
    focus: true
    clip: true

    property int keyboardIndex: 0
    property string searchText: ""
    property string mode: "insert" // "insert" or "normal"
    readonly property var filteredEntries: searchText.length > 0 ? Cliphist.fuzzyQuery(searchText) : Cliphist.entries
    readonly property string currentEntry: (keyboardIndex >= 0 && keyboardIndex < filteredEntries.length) ? filteredEntries[keyboardIndex] : ""
    readonly property bool currentIsImage: currentEntry !== "" && Cliphist.entryIsImage(currentEntry)

    onActiveFocusChanged: {
        if (!activeFocus && visible && show && mode === "normal")
            clipboardDialog.forceActiveFocus();
    }

    function loadCurrentPreview() {
        if (currentEntry && !currentIsImage) {
            textDecoder.running = false;
            textDecoder.command = ["bash", "-c", `printf '${StringUtils.shellSingleQuoteEscape(currentEntry)}' | ${Cliphist.cliphistBinary} decode`];
            textDecoder.running = true;
        } else {
            textDecoder.running = false;
            textDecoder.decodedText = "";
        }
    }

    function copySelected() {
        if (keyboardIndex >= 0 && keyboardIndex < filteredEntries.length) {
            Cliphist.paste(filteredEntries[keyboardIndex]);
            clipboardDialog.dismiss();
        }
    }

    function deleteSelected() {
        if (keyboardIndex >= 0 && keyboardIndex < filteredEntries.length)
            Cliphist.deleteEntry(filteredEntries[keyboardIndex]);
    }

    onCurrentEntryChanged: loadCurrentPreview()

    Component.onCompleted: loadCurrentPreview()

    onVisibleChanged: {
        if (visible) {
            keyboardIndex = 0;
            searchText = "";
            searchField.text = "";
            mode = "normal";
            clipboardDialog.forceActiveFocus();
            Cliphist.refresh();
            loadCurrentPreview();
        }
    }

    Process {
        id: textDecoder
        property string decodedText: ""
        stdout: StdioCollector {
            onStreamFinished: textDecoder.decodedText = text
        }
    }

    Connections {
        target: Cliphist
        function onEntriesChanged() {
            if (keyboardIndex >= filteredEntries.length)
                keyboardIndex = Math.max(0, filteredEntries.length - 1);
        }
    }

    function enterInsertMode() {
        mode = "insert";
        searchField.forceActiveFocus();
    }

    function enterNormalMode() {
        mode = "normal";
        clipboardDialog.forceActiveFocus();
    }

    Keys.onPressed: event => {
        // In insert mode, search field has focus — only handle Escape
        if (mode === "insert") {
            if (event.key === Qt.Key_Escape) {
                if (searchText.length > 0) {
                    searchText = "";
                    searchField.text = "";
                } else {
                    enterNormalMode();
                }
                event.accepted = true;
            }
            return;
        }

        // Normal mode — vim-style keybindings
        if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
            event.accepted = true;
            if (filteredEntries.length > 0)
                keyboardIndex = Math.min(keyboardIndex + 1, filteredEntries.length - 1);
        } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
            event.accepted = true;
            keyboardIndex = Math.max(keyboardIndex - 1, 0);
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = true;
            copySelected();
        } else if (event.key === Qt.Key_D && event.modifiers === Qt.NoModifier) {
            event.accepted = true;
            deleteSelected();
        } else if (event.key === Qt.Key_F || event.key === Qt.Key_Slash) {
            event.accepted = true;
            enterInsertMode();
        } else if (event.key === Qt.Key_G && event.modifiers === Qt.NoModifier) {
            event.accepted = true;
            if (filteredEntries.length > 0)
                keyboardIndex = 0;
        } else if (event.key === Qt.Key_G && event.modifiers === Qt.ShiftModifier) {
            event.accepted = true;
            if (filteredEntries.length > 0)
                keyboardIndex = filteredEntries.length - 1;
        } else if (event.key === Qt.Key_Q || event.key === Qt.Key_Escape) {
            event.accepted = true;
            clipboardDialog.dismiss();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        // Search bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: TuiStyle.panel

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                // Mode indicator
                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 18
                    color: clipboardDialog.mode === "insert" ? TuiStyle.accent : TuiStyle.bg
                    border.width: TuiStyle.borderWidth
                    border.color: clipboardDialog.mode === "insert" ? TuiStyle.accent : TuiStyle.line

                    StyledText {
                        anchors.centerIn: parent
                        text: clipboardDialog.mode === "insert" ? "INS" : "NRM"
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Bold
                        color: clipboardDialog.mode === "insert" ? TuiStyle.bg : TuiStyle.fg
                    }
                }

                StyledText {
                    text: "/"
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Bold
                    color: clipboardDialog.mode === "insert" ? TuiStyle.accent : TuiStyle.dim
                }

                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    placeholderText: "SEARCH..."
                    placeholderTextColor: TuiStyle.dim
                    color: TuiStyle.fg
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                    focus: true
                    background: null
                    onTextChanged: {
                        clipboardDialog.searchText = text;
                        clipboardDialog.keyboardIndex = 0;
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            event.accepted = true;
                            if (clipboardDialog.searchText.length > 0) {
                                clipboardDialog.searchText = "";
                                text = "";
                            } else {
                                clipboardDialog.enterNormalMode();
                            }
                        }
                    }
                }

                StyledText {
                    text: clipboardDialog.searchText.length > 0 ? `${filteredEntries.length}/${Cliphist.entries.length}` : `${Cliphist.entries.length}`
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Bold
                    color: TuiStyle.dim
                }
            }
        }

        // Content
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            // History list
            Rectangle {
                Layout.preferredWidth: 520
                Layout.fillHeight: true
                color: TuiStyle.panel
                clip: true

                ListView {
                    id: clipboardList
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true
                    spacing: 0
                    boundsBehavior: Flickable.StopAtBounds
                    boundsMovement: Flickable.StopAtBounds
                    highlightMoveDuration: 80
                    highlightResizeDuration: 0
                    interactive: true

                    model: ScriptModel {
                        values: filteredEntries
                    }

                    delegate: ClipboardItem {
                        required property string modelData
                        required property int index
                        entry: modelData
                        itemIndex: index
                        width: clipboardList.width
                        selected: clipboardDialog.keyboardIndex === index
                        onItemClicked: clipboardDialog.dismiss()
                        onHoveredChanged: {
                            if (hovered)
                                clipboardDialog.keyboardIndex = index;
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: clipboardList.count === 0
                        text: clipboardDialog.searchText.length > 0 ? "NO MATCHES" : "NO CLIPBOARD HISTORY"
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Bold
                        color: TuiStyle.dim
                    }

                    Connections {
                        target: clipboardDialog
                        function onKeyboardIndexChanged() {
                            if (clipboardDialog.keyboardIndex >= 0 && clipboardDialog.keyboardIndex < clipboardList.count)
                                clipboardList.positionViewAtIndex(clipboardDialog.keyboardIndex, ListView.Contain);
                        }
                    }
                }

                // TUI scrollbar — floats above ListView
                Item {
                    z: 2
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 6
                    visible: clipboardList.contentHeight > clipboardList.height

                    Rectangle {
                        id: scrollbarThumb
                        anchors.right: parent.right
                        width: 4
                        radius: 0
                        color: TuiStyle.dim
                        y: {
                            var trackH = clipboardList.height - 2
                            var ratio = clipboardList.contentY / clipboardList.contentHeight
                            return Math.max(0, Math.min(trackH - height, ratio * trackH)) + 1
                        }
                        height: {
                            var trackH = clipboardList.height - 2
                            var h = clipboardList.height * clipboardList.height / clipboardList.contentHeight
                            return Math.max(24, Math.min(trackH, h))
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -2
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            property real startY: 0
                            property real startContentY: 0
                            onPressed: {
                                startY = mouseY
                                startContentY = clipboardList.contentY
                            }
                            onPositionChanged: {
                                var delta = (mouseY - startY) * clipboardList.contentHeight / clipboardList.height
                                clipboardList.contentY = Math.max(0, Math.min(clipboardList.contentHeight - clipboardList.height, startContentY + delta))
                            }
                        }
                    }
                }
            }

            // Preview
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: TuiStyle.panel
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    StyledText {
                        text: clipboardDialog.currentIsImage ? "IMAGE" : clipboardDialog.currentEntry !== "" ? "TEXT" : "--"
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Bold
                        color: TuiStyle.dim
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: TuiStyle.bg
                        clip: true

                        CliphistImage {
                            anchors.centerIn: parent
                            visible: clipboardDialog.currentIsImage
                            entry: visible ? clipboardDialog.currentEntry : ""
                            maxWidth: parent.width - 24
                            maxHeight: parent.height - 24
                        }

                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 8
                            visible: clipboardDialog.currentEntry !== "" && !clipboardDialog.currentIsImage
                            clip: true

                            TextArea {
                                readOnly: true
                                selectByMouse: true
                                wrapMode: TextEdit.Wrap
                                text: textDecoder.decodedText
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: TuiStyle.fg
                                selectedTextColor: TuiStyle.bg
                                selectionColor: TuiStyle.accent
                                background: Rectangle {
                                    color: TuiStyle.bg
                                }
                                activeFocusOnPress: false
                                padding: 8
                            }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            visible: clipboardDialog.currentEntry === ""
                            text: "NO ITEM SELECTED"
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Bold
                            color: TuiStyle.dim
                        }
                    }
                }
            }
        }

        // Footer
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                spacing: 16

                FooterText {
                    text: clipboardDialog.keyboardIndex >= 0 && filteredEntries.length > 0 ? `${clipboardDialog.keyboardIndex + 1}/${filteredEntries.length}` : "-/-"
                }
                FooterText { text: "ENTER PASTE" }
                FooterText { text: "D DELETE" }
                FooterText { text: clipboardDialog.mode === "insert" ? "ESC NORMAL" : "F SEARCH" }
                FooterText { text: "Q CLOSE" }
                Item { Layout.fillWidth: true }
                FooterText { text: Cliphist.cliphistBinary.toUpperCase() }
            }
        }
    }

    component FooterText: StyledText {
        font.family: Appearance.font.family.monospace
        font.pixelSize: Appearance.font.pixelSize.smaller
        font.weight: Font.Bold
        color: TuiStyle.dim
    }
}
