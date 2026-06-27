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

    width: 860
    height: 520
    color: TuiStyle.bg
    border.color: TuiStyle.line
    border.width: TuiStyle.borderWidth
    radius: TuiStyle.radius
    focus: true
    clip: true

    property int keyboardIndex: 0
    readonly property string currentEntry: (keyboardIndex >= 0 && keyboardIndex < Cliphist.entries.length) ? Cliphist.entries[keyboardIndex] : ""
    readonly property bool currentIsImage: currentEntry !== "" && Cliphist.entryIsImage(currentEntry)

    onActiveFocusChanged: {
        if (!activeFocus && visible && show)
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
        if (keyboardIndex >= 0 && keyboardIndex < Cliphist.entries.length) {
            Cliphist.paste(Cliphist.entries[keyboardIndex]);
            clipboardDialog.dismiss();
        }
    }

    function deleteSelected() {
        if (keyboardIndex >= 0 && keyboardIndex < Cliphist.entries.length)
            Cliphist.deleteEntry(Cliphist.entries[keyboardIndex]);
    }

    onCurrentEntryChanged: loadCurrentPreview()

    Component.onCompleted: loadCurrentPreview()

    onVisibleChanged: {
        if (visible) {
            keyboardIndex = 0;
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
            if (keyboardIndex >= Cliphist.entries.length)
                keyboardIndex = Math.max(0, Cliphist.entries.length - 1);
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
            event.accepted = true;
            if (Cliphist.entries.length > 0)
                keyboardIndex = Math.min(keyboardIndex + 1, Cliphist.entries.length - 1);
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
            event.accepted = true;
            keyboardIndex = Math.max(keyboardIndex - 1, 0);
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = true;
            copySelected();
        } else if (event.key === Qt.Key_D && event.modifiers === Qt.NoModifier) {
            event.accepted = true;
            deleteSelected();
        } else if (event.key === Qt.Key_Q || event.key === Qt.Key_Escape) {
            event.accepted = true;
            clipboardDialog.dismiss();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            color: TuiStyle.panel
            border.width: TuiStyle.borderWidth
            border.color: TuiStyle.line

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                StyledText {
                    text: "CLIPBOARD"
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Bold
                    color: TuiStyle.accent
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: TuiStyle.borderWidth
                    color: TuiStyle.line
                }

                StyledText {
                    text: Cliphist.entries.length > 0 ? "READY" : "EMPTY"
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Bold
                    color: TuiStyle.muted
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 390
                Layout.fillHeight: true
                color: TuiStyle.panel
                border.width: TuiStyle.borderWidth
                border.color: TuiStyle.line
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    PanelHeader {
                        title: "HISTORY"
                        value: `${Cliphist.entries.length} ITEMS`
                    }

                    ListView {
                        id: clipboardList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 0
                        boundsBehavior: Flickable.StopAtBounds
                        boundsMovement: Flickable.StopAtBounds
                        highlightMoveDuration: 80
                        highlightResizeDuration: 0
                        interactive: true

                        model: ScriptModel {
                            values: Cliphist.entries
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

                        Rectangle {
                            anchors.centerIn: parent
                            visible: clipboardList.count === 0
                            width: emptyText.implicitWidth + 28
                            height: 34
                            color: TuiStyle.bg
                            border.width: TuiStyle.borderWidth
                            border.color: TuiStyle.line

                            StyledText {
                                id: emptyText
                                anchors.centerIn: parent
                                text: "NO CLIPBOARD HISTORY"
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Bold
                                color: TuiStyle.dim
                            }
                        }

                        Connections {
                            target: clipboardDialog
                            function onKeyboardIndexChanged() {
                                if (clipboardDialog.keyboardIndex >= 0 && clipboardDialog.keyboardIndex < clipboardList.count)
                                    clipboardList.positionViewAtIndex(clipboardDialog.keyboardIndex, ListView.Contain);
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: TuiStyle.panel
                border.width: TuiStyle.borderWidth
                border.color: TuiStyle.line
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    PanelHeader {
                        title: "PREVIEW"
                        value: clipboardDialog.currentIsImage ? "IMAGE" : clipboardDialog.currentEntry !== "" ? "TEXT" : "--"
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: TuiStyle.bg
                        border.width: TuiStyle.borderWidth
                        border.color: TuiStyle.line
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

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            color: TuiStyle.panel
            border.width: TuiStyle.borderWidth
            border.color: TuiStyle.line

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 16

                FooterText {
                    text: clipboardDialog.keyboardIndex >= 0 && Cliphist.entries.length > 0 ? `${clipboardDialog.keyboardIndex + 1}/${Cliphist.entries.length}` : "-/-"
                }
                FooterText { text: "ENTER PASTE" }
                FooterText { text: "D DELETE" }
                FooterText { text: "J/K NAV" }
                FooterText { text: "Q CLOSE" }
                Item { Layout.fillWidth: true }
                FooterText { text: Cliphist.cliphistBinary.toUpperCase() }
            }
        }
    }

    component PanelHeader: Rectangle {
        id: header
        property string title: ""
        property string value: ""

        Layout.fillWidth: true
        Layout.preferredHeight: 28
        color: TuiStyle.bg
        border.width: TuiStyle.borderWidth
        border.color: TuiStyle.line

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            StyledText {
                text: header.title
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Bold
                color: TuiStyle.accent
            }

            Item { Layout.fillWidth: true }

            StyledText {
                text: header.value
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Bold
                color: TuiStyle.dim
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
