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

    property int keyboardIndex: 0
    property int currentPage: 0
    property int itemsPerPage: 20
    property real wheelAccum: 0
    property var pageEntries: Cliphist.entries.slice(currentPage * itemsPerPage, currentPage * itemsPerPage + itemsPerPage)
    property int totalPages: Math.max(1, Math.ceil(Cliphist.entries.length / itemsPerPage))

    readonly property string currentEntry: (keyboardIndex >= 0 && keyboardIndex < pageEntries.length) ? pageEntries[keyboardIndex] : ""

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

    onCurrentPageChanged: pageEntries = Cliphist.entries.slice(currentPage * itemsPerPage, currentPage * itemsPerPage + itemsPerPage)
    onVisibleChanged: {
        if (visible) {
            currentPage = 0;
            keyboardIndex = 0;
            pageEntries = Cliphist.entries.slice(0, itemsPerPage);
            clipboardDialog.forceActiveFocus();
            Cliphist.refresh();
            loadCurrentPreview();
        }
    }

    Connections {
        target: Cliphist
        function onEntriesChanged() {
            const newTotalPages = Math.max(1, Math.ceil(Cliphist.entries.length / itemsPerPage));
            if (currentPage >= newTotalPages) {
                currentPage = newTotalPages - 1;
                keyboardIndex = 0;
            }
            pageEntries = Cliphist.entries.slice(currentPage * itemsPerPage, currentPage * itemsPerPage + itemsPerPage);
        }
    }

    function nextPage() {
        if (currentPage < totalPages - 1) {
            currentPage++;
            keyboardIndex = 0;
        }
    }

    function prevPage() {
        if (currentPage > 0) {
            currentPage--;
            keyboardIndex = 0;
        }
    }

    function copySelected() {
        const absIndex = currentPage * itemsPerPage + keyboardIndex;
        if (absIndex >= 0 && absIndex < Cliphist.entries.length) {
            Cliphist.copy(Cliphist.entries[absIndex]);
            clipboardDialog.dismiss();
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Down) {
            event.accepted = true;
            if (pageEntries.length === 0) return;
            keyboardIndex = Math.min(keyboardIndex + 1, pageEntries.length - 1);
        } else if (event.key === Qt.Key_Up) {
            event.accepted = true;
            keyboardIndex = Math.max(keyboardIndex - 1, 0);
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = true;
            copySelected();
        } else if (event.key === Qt.Key_PageDown || event.key === Qt.Key_Right) {
            event.accepted = true;
            nextPage();
        } else if (event.key === Qt.Key_PageUp || event.key === Qt.Key_Left) {
            event.accepted = true;
            prevPage();
        }
    }

    RowLayout {
        id: layoutRow
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 16

        // Left Column: List
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
                highlightMoveDuration: 0
                interactive: false

                model: ScriptModel {
                    values: clipboardDialog.pageEntries
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

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: (event) => {
                        const r = WheelUtils.getSteps(event.angleDelta.y, clipboardDialog.wheelAccum)
                        clipboardDialog.wheelAccum = r.accum
                        const steps = r.steps
                        if (steps === 0) return
                        if (steps > 0) {
                            for (let i = 0; i < steps; i++) {
                                if (clipboardDialog.keyboardIndex > 0) {
                                    clipboardDialog.keyboardIndex--;
                                } else {
                                    clipboardDialog.prevPage();
                                    clipboardDialog.keyboardIndex = Math.min(clipboardDialog.pageEntries.length - 1, clipboardDialog.itemsPerPage - 1);
                                }
                            }
                        } else {
                            for (let i = 0; i < -steps; i++) {
                                if (clipboardDialog.keyboardIndex < clipboardDialog.pageEntries.length - 1) {
                                    clipboardDialog.keyboardIndex++;
                                } else {
                                    clipboardDialog.nextPage();
                                    clipboardDialog.keyboardIndex = 0;
                                }
                            }
                        }
                        event.accepted = true;
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
        paginationVisible: clipboardDialog.totalPages > 1
        currentPage: clipboardDialog.currentPage
        totalPages: clipboardDialog.totalPages
        onPageUp: clipboardDialog.prevPage()
        onPageDown: clipboardDialog.nextPage()
        leadingActions: [
            { type: "icon", icon: "close", callback: () => clipboardDialog.dismiss() }
        ]
        trailingActions: [
            { type: "icon", icon: "delete_sweep", color: Appearance.tiling.error, callback: () => { Cliphist.wipe(); clipboardDialog.dismiss(); } }
        ]
    }
}
