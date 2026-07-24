pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.core.runtime
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    property string query: ""
    property bool searchMode: false
    property bool menuOpen: false
    property int selectedIndex: 0
    property int maxAppResults: 5
    property int maxWindowResults: 7

    readonly property string normalizedQuery: query.trim()
    readonly property bool commandMode: normalizedQuery.startsWith(">")
    readonly property string commandText: commandMode ? normalizedQuery.slice(1).trim() : ""
    readonly property bool hasQuery: normalizedQuery.length > 0
    readonly property var appResults: hasQuery && !commandMode
        ? AppSearch.fuzzyQuery(normalizedQuery).slice(0, maxAppResults)
        : []
    readonly property var windowResults: hasQuery && !commandMode
        ? root.filterWindows(normalizedQuery).slice(0, maxWindowResults)
        : []
    readonly property int commandResultCount: commandMode && commandText.length > 0 ? 1 : 0
    readonly property int totalResults: commandResultCount + appResults.length + windowResults.length
    readonly property int popupWidth: Math.min(760, Math.max(520, width - 80))

    signal searchRequested()
    signal closeRequested()

    function windowHaystack(win) {
        const workspace = win?.workspace || {};
        return [
            win?.title || "",
            win?.initialTitle || "",
            win?.class || "",
            win?.initialClass || "",
            workspace.name || "",
            workspace.id || "",
            win?.monitor || ""
        ].join(" ").toLowerCase();
    }

    function filterWindows(text) {
        const needle = String(text || "").toLowerCase().trim();
        if (needle.length === 0)
            return [];
        return (ServiceManager.workspace.windowList || []).filter(win =>
            win && win.mapped && !win.hidden && win.address
                && root.windowHaystack(win).indexOf(needle) >= 0);
    }

    function clampSelection() {
        selectedIndex = Math.max(0, Math.min(selectedIndex, Math.max(0, totalResults - 1)));
    }

    function moveSelection(delta) {
        if (totalResults <= 0)
            return;
        selectedIndex = (selectedIndex + delta + totalResults) % totalResults;
        resultsFlickable.ensureVisible(selectedIndex);
    }

    function launchApp(app) {
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

    function executeCommand() {
        if (commandText.length === 0)
            return;
        const detach = FileUtils.trimFileProtocol(`${Directories.config}/omd/bin/omd-detach`);
        Quickshell.execDetached([
            detach,
            "xdg-terminal-exec",
            "--app-id=org.omd.overview-command",
            "--title=OMD Command",
            "--hold",
            "-e",
            "bash",
            "-lc",
            commandText
        ]);
        GlobalStates.overviewOpen = false;
    }

    function requestSessionAction(action, label) {
        menuOpen = false;
        GlobalStates.overviewOpen = false;
        const barApp = FileUtils.trimFileProtocol(`${Directories.root}/apps/omd-bar`);
        Quickshell.execDetached([
            "qs", "-p", barApp, "ipc", "call", "session", "confirm", action, label
        ]);
    }

    function reloadShell() {
        menuOpen = false;
        GlobalStates.overviewOpen = false;
        Quickshell.execDetached([
            "qs", "-p", `${Directories.scriptPath}/reload-quickshell`
        ]);
    }

    function activateSelection() {
        if (commandResultCount > 0) {
            executeCommand();
            return;
        }
        if (selectedIndex < appResults.length) {
            launchApp(appResults[selectedIndex]);
            return;
        }
        const windowIndex = selectedIndex - appResults.length;
        if (windowIndex >= 0 && windowIndex < windowResults.length)
            focusWindow(windowResults[windowIndex]);
    }

    function windowTitle(win) {
        return win?.title || win?.initialTitle || "Untitled window";
    }

    function windowProgram(win) {
        return win?.class || win?.initialClass || "Window";
    }

    function workspaceLabel(win) {
        const workspace = win?.workspace || {};
        const id = workspace.id > 0 ? workspace.id : "?";
        const monitor = win?.monitor ? `  ${win.monitor}` : "";
        return `Workspace ${id}${monitor}`;
    }

    onTotalResultsChanged: clampSelection()
    onQueryChanged: selectedIndex = 0

    // ── Search box + quick-action button (disabled per request) ──
    /*
    MouseArea {
        anchors.fill: parent
        z: 10
        visible: root.menuOpen
        onClicked: root.menuOpen = false
    }

    Item {
        id: searchHeader
        anchors {
            top: parent.top
            topMargin: 24
            horizontalCenter: parent.horizontalCenter
        }
        width: Math.min(620, Math.max(420, root.width - 96))
        height: 46
        z: 12

        Rectangle {
            id: searchField
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
                right: menuButton.left
                rightMargin: 8
            }
            radius: 8
            color: TuiStyle.surfaceRaised
            border.width: root.searchMode ? 2 : 1
            border.color: root.searchMode ? TuiStyle.controlActiveBorder : TuiStyle.menuBorder

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 12
                spacing: 10

                MaterialSymbol {
                    text: root.commandMode ? "terminal" : "search"
                    iconSize: 19
                    color: root.searchMode ? TuiStyle.accent : TuiStyle.dim
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.hasQuery
                        ? root.query
                        : "Search apps and windows, or type > for a command"
                    color: root.hasQuery ? TuiStyle.fg : TuiStyle.dim
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }

                StyledText {
                    text: root.searchMode ? "ESC" : "TYPE"
                    color: TuiStyle.dim
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onClicked: root.searchRequested()
            }
        }

        Rectangle {
            id: menuButton
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            width: 46
            radius: 8
            color: menuButtonArea.containsMouse || root.menuOpen
                ? TuiStyle.surfaceHover
                : TuiStyle.surfaceRaised
            border.width: root.menuOpen ? 2 : 1
            border.color: root.menuOpen ? TuiStyle.controlActiveBorder : TuiStyle.menuBorder

            MaterialSymbol {
                anchors.centerIn: parent
                text: "menu"
                iconSize: 21
                color: root.menuOpen ? TuiStyle.accent : TuiStyle.fg
            }

            MouseArea {
                id: menuButtonArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.menuOpen = !root.menuOpen
            }
        }
    }

    Rectangle {
        id: sessionMenu
        anchors {
            top: parent.top
            topMargin: 24
            right: parent.right
            rightMargin: 8
        }
        width: 230
        implicitHeight: sessionMenuColumn.implicitHeight + 12
        visible: root.menuOpen
        z: 13
        radius: 8
        color: TuiStyle.bg
        border.width: 1
        border.color: TuiStyle.menuBorder

        ColumnLayout {
            id: sessionMenuColumn
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            SessionMenuItem {
                Layout.fillWidth: true
                symbol: "logout"
                label: "Log out"
                onActivated: root.requestSessionAction("logout", "Logout")
            }
            SessionMenuItem {
                Layout.fillWidth: true
                symbol: "restart_alt"
                label: "Restart"
                onActivated: root.requestSessionAction("reboot", "Reboot")
            }
            SessionMenuItem {
                Layout.fillWidth: true
                symbol: "power_settings_new"
                label: "Shut down"
                onActivated: root.requestSessionAction("poweroff", "Shutdown")
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                implicitHeight: 1
                color: TuiStyle.line
                opacity: TuiStyle.dividerOpacity
            }

            SessionMenuItem {
                Layout.fillWidth: true
                symbol: "refresh"
                label: "Reload Shell"
                onActivated: root.reloadShell()
            }
        }
    }
    */

    Rectangle {
        id: resultsPopup
        anchors {
            top: parent.top
            topMargin: 24
            horizontalCenter: parent.horizontalCenter
        }
        width: root.popupWidth
        height: Math.min(resultsColumn.implicitHeight + 20, Math.max(180, root.height - y - 32))
        visible: root.searchMode && root.hasQuery
        radius: 8
        color: TuiStyle.bg
        border.width: 1
        border.color: TuiStyle.menuBorder
        clip: true

        Flickable {
            id: resultsFlickable
            anchors.fill: parent
            anchors.margins: 10
            contentWidth: width
            contentHeight: resultsColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            function ensureVisible(index) {
                const rowHeight = 54;
                const targetY = Math.max(0, index * rowHeight - 28);
                if (targetY < contentY)
                    contentY = targetY;
                else if (targetY + rowHeight > contentY + height)
                    contentY = Math.min(contentHeight - height, targetY + rowHeight - height);
            }

            ColumnLayout {
                id: resultsColumn
                width: resultsFlickable.width
                spacing: 6

                SearchResultRow {
                    Layout.fillWidth: true
                    visible: root.commandResultCount > 0
                    resultIndex: 0
                    title: root.commandText
                    subtitle: "Open an independent terminal and run this command"
                    meta: "Terminal command"
                    symbol: "terminal"
                    selected: root.selectedIndex === resultIndex
                    onActivated: root.executeCommand()
                }

                SearchSectionHeader {
                    Layout.fillWidth: true
                    visible: root.appResults.length > 0
                    label: "Applications"
                    count: root.appResults.length
                }

                Repeater {
                    model: root.appResults

                    SearchResultRow {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        resultIndex: index
                        title: modelData?.name || ""
                        subtitle: modelData?.comment || modelData?.genericName || modelData?.id || ""
                        meta: "New workspace"
                        iconSource: AppSearch.iconSource(modelData?.icon || "")
                        selected: root.selectedIndex === resultIndex
                        onActivated: root.launchApp(modelData)
                    }
                }

                SearchSectionHeader {
                    Layout.fillWidth: true
                    visible: root.windowResults.length > 0
                    label: "Open Windows"
                    count: root.windowResults.length
                }

                Repeater {
                    model: root.windowResults

                    SearchResultRow {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        resultIndex: root.appResults.length + index
                        title: root.windowTitle(modelData)
                        subtitle: root.windowProgram(modelData)
                        meta: root.workspaceLabel(modelData)
                        iconSource: AppSearch.iconSource(AppSearch.guessIcon(root.windowProgram(modelData)))
                        selected: root.selectedIndex === resultIndex
                        onActivated: root.focusWindow(modelData)
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    visible: root.totalResults === 0
                    text: root.commandMode
                        ? "Type a command after >"
                        : "No matching applications or windows"
                    color: TuiStyle.dim
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 13
                }
            }
        }
    }

    component SearchSectionHeader: Item {
        required property string label
        property int count: 0
        implicitHeight: 26

        StyledText {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                leftMargin: 8
                rightMargin: 8
            }
            height: 20
            text: `${parent.label}  ${parent.count}`
            color: TuiStyle.dim
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
    }

    component SessionMenuItem: Rectangle {
        id: menuItem
        required property string symbol
        required property string label
        signal activated()

        implicitHeight: 42
        radius: 6
        color: menuItemArea.containsMouse ? TuiStyle.surfaceHover : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            spacing: 11

            MaterialSymbol {
                text: menuItem.symbol
                iconSize: 19
                color: TuiStyle.fg
            }
            StyledText {
                Layout.fillWidth: true
                text: menuItem.label
                color: TuiStyle.fg
                font.pixelSize: 13
            }
        }

        MouseArea {
            id: menuItemArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menuItem.activated()
        }
    }

    component SearchResultRow: Rectangle {
        id: row
        required property int resultIndex
        required property string title
        property string subtitle: ""
        property string meta: ""
        property string iconSource: ""
        property string symbol: "apps"
        property bool selected: false
        signal activated()

        implicitHeight: 54
        radius: 6
        color: selected ? TuiStyle.selection : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 12
            spacing: 11

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 6
                color: row.selected ? TuiStyle.accentWash(TuiStyle.accent) : TuiStyle.surfaceSubtle

                Image {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    source: row.iconSource
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: status === Image.Ready
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: row.symbol
                    iconSize: 21
                    color: row.selected ? TuiStyle.accent : TuiStyle.dim
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
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: row.subtitle
                    color: TuiStyle.dim
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            StyledText {
                Layout.maximumWidth: 210
                text: row.meta
                color: row.selected ? TuiStyle.fg : TuiStyle.dim
                font.pixelSize: 11
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.selectedIndex = row.resultIndex
            onClicked: row.activated()
        }
    }
}
