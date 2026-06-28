pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    property bool active: true
    property string seedText: "" // Initial char forwarded from workspace mode
    property string query: input.text.trim()
    property int selectedFlatIndex: 0
    property int maxAppResults: 5
    property int maxWindowResults: 8
    property int focusAttempts: 0
    readonly property bool searchMode: GlobalStates.overviewSearchMode
    readonly property bool hasQuery: query.length > 0
    readonly property var appResults: hasQuery ? AppSearch.fuzzyQuery(query).slice(0, maxAppResults) : []
    readonly property var windowResults: root.filterWindows(query).slice(0, maxWindowResults)
    readonly property int totalResults: appResults.length + windowResults.length
    readonly property int popoverWidth: Math.min(740, Math.max(500, root.width - 64))

    implicitWidth: parent ? parent.width : 720
    implicitHeight: searchShell.implicitHeight + (resultsPopup.visible ? resultsPopup.implicitHeight + 10 : 0)

    function windowHaystack(win) {
        if (!win)
            return "";
        const workspace = win.workspace || {};
        return [
            win.title || "",
            win.initialTitle || "",
            win.class || "",
            win.initialClass || "",
            workspace.name || "",
            workspace.id || "",
            win.monitor || ""
        ].join(" ").toLowerCase();
    }

    function filterWindows(text) {
        const q = (text || "").toLowerCase().trim();
        if (q.length === 0)
            return [];

        const results = [];
        const windows = HyprlandData.windowList || [];
        for (let i = 0; i < windows.length; i++) {
            const win = windows[i];
            if (!win || !win.mapped || win.hidden || !win.address)
                continue;
            if (root.windowHaystack(win).indexOf(q) < 0)
                continue;
            results.push(win);
        }
        return results;
    }

    function clampSelection() {
        selectedFlatIndex = Math.max(0, Math.min(selectedFlatIndex, Math.max(0, totalResults - 1)));
    }

    function moveSelection(delta) {
        if (totalResults <= 0)
            return;
        selectedFlatIndex = (selectedFlatIndex + delta + totalResults) % totalResults;
    }

    function selectedIsApp(index) {
        return index < appResults.length;
    }

    function selectedApp(index) {
        if (!selectedIsApp(index))
            return null;
        return appResults[index];
    }

    function selectedWindow(index) {
        const windowIndex = index - appResults.length;
        if (windowIndex < 0 || windowIndex >= windowResults.length)
            return null;
        return windowResults[windowIndex];
    }

    function launchAppOnNewWorkspace(app) {
        if (!app)
            return;
        Hyprland.dispatch('hl.dsp.focus({ workspace = "empty" })');
        Qt.callLater(() => {
            AppSearch.launchApp(app);
            GlobalStates.overviewOpen = false;
        });
    }

    function focusWindow(win) {
        if (!win)
            return;
        WorkspaceNavigation.focusWindow(win);
        GlobalStates.overviewOpen = false;
    }

    function activateSelection() {
        if (!hasQuery)
            return;

        const app = selectedApp(selectedFlatIndex);
        if (app) {
            launchAppOnNewWorkspace(app);
            return;
        }

        const win = selectedWindow(selectedFlatIndex);
        if (win)
            focusWindow(win);
    }

    function windowTitle(win) {
        return win?.title || win?.initialTitle || Translation.tr("Untitled window");
    }

    function windowProgram(win) {
        return win?.class || win?.initialClass || Translation.tr("Window");
    }

    function workspaceLabel(win) {
        const workspace = win?.workspace || {};
        const id = workspace.id > 0 ? workspace.id : "?";
        const name = workspace.name && workspace.name !== id.toString() ? `:${workspace.name}` : "";
        const monitor = win?.monitor ? ` @ ${win.monitor}` : "";
        return `WS ${id}${name}${monitor}`;
    }

    onTotalResultsChanged: clampSelection()
    onQueryChanged: selectedFlatIndex = 0

    function requestInputFocus() {
        if (!active || !GlobalStates.overviewOpen || !GlobalStates.overviewSearchMode)
            return;
        focusAttempts = 0;
        input.forceActiveFocus();
        focusRetryTimer.restart();
    }

    onSearchModeChanged: {
        if (searchMode) {
            if (seedText.length > 0) {
                input.text = seedText;
                seedText = "";
            }
            Qt.callLater(requestInputFocus);
        } else {
            input.text = "";
            selectedFlatIndex = 0;
        }
    }

    onSeedTextChanged: {
        if (searchMode && seedText.length > 0) {
            input.text = seedText;
            seedText = "";
        }
    }

    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            if (!GlobalStates.overviewOpen) {
                focusRetryTimer.stop();
                input.text = "";
                selectedFlatIndex = 0;
            }
        }
    }

    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            if (GlobalStates.overviewOpen && GlobalStates.overviewSearchMode)
                Qt.callLater(root.requestInputFocus);
        }
    }

    Timer {
        id: focusRetryTimer
        interval: 45
        repeat: true
        onTriggered: {
            if (!root.active || !GlobalStates.overviewOpen || !GlobalStates.overviewSearchMode || input.activeFocus || root.focusAttempts >= 8) {
                stop();
                return;
            }
            root.focusAttempts++;
            input.forceActiveFocus();
        }
    }

    Rectangle {
        id: searchShell
        width: Math.min(430, Math.max(300, root.width - 64))
        height: 40
        anchors.horizontalCenter: parent.horizontalCenter
        radius: TuiStyle.radius
        color: "#181818"
        border.width: 0
        visible: root.searchMode
        opacity: root.searchMode ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            spacing: 9

            MaterialSymbol {
                text: "search"
                iconSize: 18
                color: input.activeFocus ? TuiStyle.fg : TuiStyle.dim
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                StyledText {
                    anchors.fill: parent
                    text: Translation.tr("Type to search")
                    color: TuiStyle.dim
                    opacity: input.text.length === 0 ? 0.9 : 0
                    font.pixelSize: 13
                }

                TextField {
                    id: input
                    anchors.fill: parent
                    focus: root.searchMode
                    background: null
                    padding: 0
                    color: TuiStyle.fg
                    selectedTextColor: TuiStyle.bg
                    selectionColor: TuiStyle.accent
                    font.family: Appearance.font.family.main
                    font.pixelSize: 13
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    renderType: Text.NativeRendering

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            GlobalStates.overviewSearchMode = false;
                            event.accepted = true;
                            return;
                        }
                        if (event.key === Qt.Key_Backspace && input.text.length === 0) {
                            GlobalStates.overviewSearchMode = false;
                            event.accepted = true;
                            return;
                        }
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.activateSelection();
                            event.accepted = true;
                            return;
                        }
                        if (event.key === Qt.Key_Down || (event.key === Qt.Key_J && (event.modifiers & Qt.ControlModifier))) {
                            root.moveSelection(1);
                            event.accepted = true;
                            return;
                        }
                        if (event.key === Qt.Key_Up || (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier))) {
                            root.moveSelection(-1);
                            event.accepted = true;
                        }
                    }
                }
            }

            MaterialSymbol {
                text: "close"
                iconSize: 16
                color: TuiStyle.dim
                opacity: input.text.length > 0 ? 1 : 0
                Layout.alignment: Qt.AlignVCenter

                MouseArea {
                    anchors.fill: parent
                    enabled: parent.opacity > 0
                    cursorShape: Qt.PointingHandCursor
                    onClicked: input.text = ""
                }
            }
        }
    }

    Rectangle {
        id: resultsPopup
        anchors.top: searchShell.bottom
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.popoverWidth
        implicitHeight: resultsLayout.implicitHeight + 24
        visible: root.searchMode && root.hasQuery
        opacity: visible ? 1 : 0
        radius: TuiStyle.radius
        color: "#181818"
        border.width: 0

        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            id: resultsLayout
            anchors.fill: parent
            anchors.margins: 12
            spacing: 7

            SearchSectionHeader {
                label: Translation.tr("Applications")
                count: root.appResults.length
            }

            Repeater {
                model: root.appResults

                SearchResultRow {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    title: modelData?.name || ""
                    subtitle: modelData?.comment || modelData?.genericName || modelData?.id || ""
                    meta: Translation.tr("Enter: launch in new workspace")
                    iconSource: AppSearch.iconSource(modelData?.icon || "")
                    selected: root.selectedFlatIndex === index
                    onActivated: root.launchAppOnNewWorkspace(modelData)
                }
            }

            SearchSectionHeader {
                label: Translation.tr("Open Windows")
                count: root.windowResults.length
                topPadding: root.appResults.length > 0 ? 4 : 0
            }

            Repeater {
                model: root.windowResults

                SearchResultRow {
                    required property var modelData
                    required property int index

                    readonly property int flatIndex: root.appResults.length + index

                    Layout.fillWidth: true
                    title: root.windowTitle(modelData)
                    subtitle: root.windowProgram(modelData)
                    meta: root.workspaceLabel(modelData)
                    iconSource: AppSearch.iconSource(AppSearch.guessIcon(root.windowProgram(modelData)))
                    selected: root.selectedFlatIndex === flatIndex
                    onActivated: root.focusWindow(modelData)
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                text: Translation.tr("No matches")
                color: TuiStyle.dim
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 13
                visible: root.totalResults === 0
            }
        }
    }

    component SearchSectionHeader: Item {
        required property string label
        property int count: 0
        property int topPadding: 0

        Layout.fillWidth: true
        Layout.preferredHeight: 24 + topPadding

        StyledText {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 18
            text: `${label}  ${count}`
            color: TuiStyle.dim
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }

    component SearchResultRow: Rectangle {
        id: row

        required property string title
        property string subtitle: ""
        property string meta: ""
        property string iconSource: ""
        property bool selected: false
        signal activated()

        implicitHeight: 50
        radius: TuiStyle.radius
        color: selected ? TuiStyle.selection : "#222222"
        border.width: 0

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 11

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: TuiStyle.radius
                color: selected ? "#ffffff26" : "#2b2b2b"

                Image {
                    anchors.centerIn: parent
                    width: 23
                    height: 23
                    source: row.iconSource
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: status === Image.Ready
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "apps"
                    iconSize: 21
                    color: TuiStyle.dim
                    visible: row.iconSource.length === 0
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: row.title
                    color: TuiStyle.fg
                    font.pixelSize: 14
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                StyledText {
                    Layout.fillWidth: true
                    text: row.subtitle
                    color: selected ? TuiStyle.fg : TuiStyle.dim
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: text.length > 0
                }
            }

            StyledText {
                Layout.maximumWidth: 230
                text: row.meta
                color: selected ? TuiStyle.fg : TuiStyle.dim
                font.pixelSize: 12
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.activated()
        }
    }
}
