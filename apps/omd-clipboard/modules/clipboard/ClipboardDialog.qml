import "widgets"
import "../../services"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: clipboardDialog

    property bool show: false
    property real cursorGlobalX: 0
    property real cursorGlobalY: 0
    property real screenGlobalX: 0
    property real screenGlobalY: 0
    property var screen: null
    property int keyboardIndex: 0
    property int hoveredIndex: -1
    property string searchText: ""
    property bool previewRequested: false
    signal dismiss()

    readonly property int edgeMargin: 14
    readonly property int menuWidth: Math.min(460, Math.max(340, width - edgeMargin * 2))
    readonly property int previewWidth: Math.min(380, Math.max(300, width - edgeMargin * 2))
    readonly property int maxVisibleRows: Math.floor(((screen?.height ?? 720) * 0.7 - 80) / 34)
    readonly property int visibleRows: Math.min(maxVisibleRows, Math.max(1, filteredEntries.length))
    readonly property int menuHeight: 48 + visibleRows * 34 + 32
    readonly property var filteredEntries: searchText.length > 0 ? Cliphist.fuzzyQuery(searchText) : Cliphist.entries
    readonly property string selectedEntry: keyboardIndex >= 0 && keyboardIndex < filteredEntries.length ? filteredEntries[keyboardIndex] : ""
    readonly property string hoveredEntry: hoveredIndex >= 0 && hoveredIndex < filteredEntries.length ? filteredEntries[hoveredIndex] : ""
    readonly property string previewEntry: previewRequested && hoveredEntry !== "" ? hoveredEntry : ""
    readonly property bool previewIsImage: previewEntry !== "" && Cliphist.entryIsImage(previewEntry)
    readonly property bool previewOnLeft: menuCard.x + menuWidth + 10 + previewWidth > width - edgeMargin

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value));
    }

    function placeAtCursor() {
        if (!menuCard)
            return;
        const localX = cursorGlobalX - screenGlobalX;
        const localY = cursorGlobalY - screenGlobalY;
        menuCard.x = clamp(localX, edgeMargin, Math.max(edgeMargin, width - menuWidth - edgeMargin));
        menuCard.y = clamp(localY, edgeMargin, Math.max(edgeMargin, height - menuHeight - edgeMargin));
    }

    function pasteSelected(asPath) {
        if (selectedEntry === "")
            return;
        const entry = selectedEntry;
        clipboardDialog.dismiss();
        if (asPath && Cliphist.entryIsImage(entry))
            Cliphist.pasteImagePath(entry);
        else
            Cliphist.paste(entry);
    }

    function deleteSelected() {
        if (selectedEntry !== "")
            Cliphist.deleteEntry(selectedEntry);
    }

    function loadPreview() {
        if (!previewRequested || previewEntry === "" || previewIsImage) {
            textDecoder.running = false;
            textDecoder.decodedText = "";
            return;
        }
        textDecoder.running = false;
        textDecoder.decodedText = "";
        textDecoder.command = ["bash", "-c", `printf '${StringUtils.shellSingleQuoteEscape(previewEntry)}' | ${Cliphist.cliphistBinary} decode`];
        textDecoder.running = true;
    }

    onPreviewEntryChanged: loadPreview()
    onWidthChanged: if (show) placeAtCursor()
    onHeightChanged: if (show) placeAtCursor()

    onVisibleChanged: {
        if (visible) {
            keyboardIndex = 0;
            hoveredIndex = -1;
            previewRequested = false;
            searchText = "";
            searchField.text = "";
            Cliphist.setDialogVisible(true);
            Qt.callLater(() => {
                placeAtCursor();
                searchField.forceActiveFocus();
            });
        } else {
            Cliphist.setDialogVisible(false);
        }
    }

    Connections {
        target: Cliphist
        function onEntriesChanged() {
            clipboardDialog.keyboardIndex = Math.min(clipboardDialog.keyboardIndex, Math.max(0, clipboardDialog.filteredEntries.length - 1));
        }
    }

    Process {
        id: textDecoder
        property string decodedText: ""
        stdout: StdioCollector {
            onStreamFinished: textDecoder.decodedText = text
        }
    }

    Timer {
        id: previewDelay
        interval: 180
        repeat: false
        onTriggered: clipboardDialog.previewRequested = clipboardDialog.hoveredIndex >= 0
    }

    Rectangle {
        id: menuCard
        width: clipboardDialog.menuWidth
        height: clipboardDialog.menuHeight
        color: "#1e1e22"
        border.color: "#3c3c42"
        border.width: 1
        radius: 10
        clip: true
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Down) {
                event.accepted = true;
                keyboardIndex = Math.min(keyboardIndex + 1, filteredEntries.length - 1);
            } else if (event.key === Qt.Key_Up) {
                event.accepted = true;
                keyboardIndex = Math.max(0, keyboardIndex - 1);
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                event.accepted = true;
                pasteSelected((event.modifiers & Qt.ControlModifier) !== 0);
            } else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                event.accepted = true;
                deleteSelected();
            } else if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                dismiss();
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Top Padded胶囊搜索栏 (Maccy Style)
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 48

                Rectangle {
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 10
                        topMargin: 10
                        bottomMargin: 6
                    }
                    radius: 6
                    color: "#282830"
                    border.width: 1
                    border.color: "#3a3a40"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        StyledText {
                            text: "search"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 16
                            color: TuiStyle.dim
                        }

                        TextInput {
                            id: searchField
                            Layout.fillWidth: true
                            color: TuiStyle.fg
                            selectionColor: TuiStyle.accent
                            selectedTextColor: TuiStyle.bg
                            font.family: Appearance.font.family.main
                            font.pixelSize: 13
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            onTextChanged: {
                                clipboardDialog.searchText = text;
                                clipboardDialog.keyboardIndex = 0;
                            }
                            Keys.forwardTo: [menuCard]

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: parent.text.length === 0
                                text: "Type to search..."
                                color: "#85858a"
                                font.pixelSize: 13
                            }
                        }
                    }
                }
            }

            ListView {
                id: clipboardList
                Layout.fillWidth: true
                Layout.preferredHeight: clipboardDialog.visibleRows * 34
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel { values: filteredEntries }

                delegate: ClipboardItem {
                    required property string modelData
                    required property int index
                    entry: modelData
                    itemIndex: index
                    width: clipboardList.width
                    selected: clipboardDialog.keyboardIndex === index
                    onItemClicked: clipboardDialog.dismiss()
                    onPasteAsPathRequested: entry => {
                        clipboardDialog.dismiss();
                        Cliphist.pasteImagePath(entry);
                    }
                    onHoveredChanged: hovered => {
                        if (hovered) {
                            clipboardDialog.keyboardIndex = index;
                            clipboardDialog.hoveredIndex = index;
                            clipboardDialog.previewRequested = false;
                            previewDelay.restart();
                        } else if (clipboardDialog.hoveredIndex === index) {
                            previewDelay.stop();
                            clipboardDialog.hoveredIndex = -1;
                            clipboardDialog.previewRequested = false;
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: clipboardList.count === 0
                    text: clipboardDialog.searchText.length > 0 ? "No matches" : "Clipboard is empty"
                    color: TuiStyle.dim
                    font.pixelSize: 14
                }

                Connections {
                    target: clipboardDialog
                    function onKeyboardIndexChanged() {
                        if (clipboardDialog.keyboardIndex >= 0 && clipboardDialog.keyboardIndex < clipboardList.count)
                            clipboardList.positionViewAtIndex(clipboardDialog.keyboardIndex, ListView.Contain);
                    }
                }
            }

            // Bottom Thin Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#2c2c32"
            }

            // Footer Link Row
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 32

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12

                    StyledText {
                        text: "Clear history"
                        color: clearMouse.containsMouse ? TuiStyle.accent : TuiStyle.dim
                        font.pixelSize: 12

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Cliphist.wipe()
                        }
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: "Shift+Del delete  ·  Ctrl+Enter path"
                        color: "#6c6c72"
                        font.pixelSize: 10
                    }
                }
            }
        }
    }

    Rectangle {
        id: previewCard
        visible: clipboardDialog.previewRequested && clipboardDialog.previewEntry !== ""
        x: clipboardDialog.clamp(
            clipboardDialog.previewOnLeft ? menuCard.x - width - 10 : menuCard.x + menuCard.width + 10,
            clipboardDialog.edgeMargin,
            Math.max(clipboardDialog.edgeMargin, clipboardDialog.width - width - clipboardDialog.edgeMargin))
        y: clipboardDialog.clamp(menuCard.y, clipboardDialog.edgeMargin, Math.max(clipboardDialog.edgeMargin, clipboardDialog.height - height - clipboardDialog.edgeMargin))
        width: clipboardDialog.previewWidth
        height: Math.min(300, Math.max(150, menuCard.height))
        color: "#1e1e22"
        border.color: "#3c3c42"
        border.width: 1
        radius: 10
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            StyledText {
                text: clipboardDialog.previewIsImage ? "Image preview" : "Clipboard details"
                color: TuiStyle.dim
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#2d2d34" }

            CliphistImage {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: clipboardDialog.previewIsImage
                entry: visible ? clipboardDialog.previewEntry : ""
                active: visible
                maxWidth: previewCard.width - 24
                maxHeight: previewCard.height - 56
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !clipboardDialog.previewIsImage
                clip: true
                contentWidth: width
                contentHeight: previewText.paintedHeight
                boundsBehavior: Flickable.StopAtBounds

                TextEdit {
                    id: previewText
                    width: parent.width
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    text: textDecoder.decodedText
                    color: TuiStyle.fg
                    selectionColor: TuiStyle.accent
                    selectedTextColor: TuiStyle.bg
                    font.family: Appearance.font.family.main
                    font.pixelSize: 14
                }
            }
        }
    }
}
