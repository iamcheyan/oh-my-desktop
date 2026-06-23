import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: launcher
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:appLauncher"
    WlrLayershell.keyboardFocus: launcher.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; left: true; right: true; bottom: true }

    visible: launcher.open

    readonly property string stateDir: Quickshell.shellDir + "/.state"
    readonly property string stateFile: stateDir + "/pinned-apps"

    property bool open: false
    property real cardOffsetX: 0
    property real cardOffsetY: 0
    property string focusedAppDescription: ""

    function run(command) { Quickshell.execDetached(["sh", "-c", command]); }

    function quote(value) {
        return "'" + value.replace(/'/g, "'\\''") + "'";
    }

    function launchApp(desktopEntry) {
        if (!desktopEntry || !desktopEntry.command || desktopEntry.command.length === 0) return;

        const cmd = desktopEntry.command;
        let program = cmd[0];
        const args = [];
        for (let i = 1; i < cmd.length; i++) {
            if (cmd[i].startsWith("%")) continue;
            args.push(cmd[i]);
        }

        if (program.includes("/")) {
            // Already a path — launch directly with inherited env
            Quickshell.execDetached({
                command: [program].concat(args),
                workingDirectory: desktopEntry.workingDirectory || ""
            });
        } else {
            // Filter ~/.local/bin out of PATH so wrapper scripts (labwc-era)
            // don't override native Hyprland scaling.
            const q = (s) => "'" + s.replace(/'/g, "'\\''") + "'";
            Quickshell.execDetached([
                "sh", "-c",
                'p=$(echo ":$PATH:" | sed "s|:$HOME/.local/bin:|:|g" | sed "s/^://; s/:$//") && ' +
                'exec "$(PATH="$p" command -v ' + q(program) + ')" ' + args.map(q).join(" ")
            ]);
        }
        console.log("[AppLauncher] Launched " + (program.includes("/") ? program : program + " " + args.join(" ")));
    }

    function iconSource(icon) {
        if (!icon) return "";
        if (icon.startsWith("/")) return "file://" + icon;
        const resolved = Quickshell.iconPath(icon, true);
        if (resolved.startsWith("/")) return "file://" + resolved;
        if (resolved) return resolved;
        return "";
    }

    property var pinnedIds: ({})
    property var allApps: []
    property var filteredApps: []
    property var runningSet: ({})
    property bool pinnedIdsLoaded: false
    property bool appsLoaded: false

    function sameAppList(a, b) {
        if (!a || !b || a.length !== b.length) return false;
        for (let i = 0; i < a.length; i++) {
            if ((a[i]?.id ?? "") !== (b[i]?.id ?? "")) return false;
        }
        return true;
    }

    function samePinnedIds(a, b) {
        const ak = Object.keys(a || {}).filter(k => a[k]).sort();
        const bk = Object.keys(b || {}).filter(k => b[k]).sort();
        if (ak.length !== bk.length) return false;
        for (let i = 0; i < ak.length; i++) {
            if (ak[i] !== bk[i]) return false;
        }
        return true;
    }

    function updateRunningSet() {
        const set = {};
        const wl = HyprlandData.windowList || [];
        for (let i = 0; i < wl.length; i++) {
            const w = wl[i];
            if (!w || !w.mapped || w.hidden) continue;
            const cls = (w.class || "").toLowerCase();
            const initial = (w.initialClass || "").toLowerCase();
            if (cls) set[cls] = true;
            if (initial) set[initial] = true;
        }
        launcher.runningSet = set;
    }

    function isAppRunning(app) {
        if (!app) return false;
        const set = launcher.runningSet;
        if (!set) return false;
        let any = false;
        for (const _ in set) { any = true; break; }
        if (!any) return false;

        const id = (app.id || "").split("/").pop().split(".").pop().toLowerCase();
        let exec = (app.execString || "").split(" ")[0].split("/").pop().toLowerCase();
        const stripped = exec.replace(/-stable$/, "").replace(/-bin$/, "").replace(/^env-/, "");
        const candidates = [id, exec, stripped];
        for (let i = 0; i < candidates.length; i++) {
            const c = candidates[i];
            if (!c) continue;
            if (set[c]) return true;
        }
        for (const k in set) {
            if (!k) continue;
            if (k === id || k === exec || k === stripped) return true;
            if (id && (k.indexOf(id) >= 0 || id.indexOf(k) >= 0)) return true;
            if (exec && (k.indexOf(exec) >= 0 || exec.indexOf(k) >= 0)) return true;
        }
        return false;
    }

    function loadPinnedIds() {
        if (pinnedIdsLoaded) return;
        pinnedLoadProcess.running = false;
        pinnedLoadProcess.running = true;
    }

    function loadApps() {
        const entries = DesktopEntries.applications.values;
        const apps = [];
        for (let i = 0; i < entries.length; i++) {
            const app = entries[i];
            if (!app || app.noDisplay || !app.name || !app.id) continue;
            apps.push(app);
        }
        appsLoaded = true;
        if (!sameAppList(allApps, apps)) {
            allApps = apps;
        } else if (pinnedIdsLoaded) {
            buildFilteredList();
        }
    }

    function savePinnedIds() {
        const ids = [];
        for (const id in pinnedIds) {
            if (pinnedIds[id]) ids.push(id);
        }
        ids.sort();
        const payload = ids.join("\n") + (ids.length > 0 ? "\n" : "");
        launcher.run("mkdir -p " + quote(stateDir) + " && printf %s " + quote(payload) + " > " + quote(stateFile));
    }

    function togglePinned(id) {
        const copy = Object.assign({}, pinnedIds);
        if (copy[id]) delete copy[id];
        else copy[id] = true;
        pinnedIds = copy;
        savePinnedIds();
    }

    function buildFilteredList() {
        const q = searchField.text.toLowerCase().trim();
        const list = [];
        for (let i = 0; i < allApps.length; i++) {
            const app = allApps[i];
            if (!app || !app.id || !app.name) continue;
            const haystack = [
                app.name,
                app.id,
                app.execString || "",
                app.genericName || "",
                app.comment || "",
                (app.keywords || []).join(" ")
            ].join(" ").toLowerCase();
            if (q !== "" && haystack.indexOf(q) < 0) continue;
            list.push(app);
        }
        function byPriority(a, b) {
            const aRunning = isAppRunning(a) ? 1 : 0;
            const bRunning = isAppRunning(b) ? 1 : 0;
            const aPinned = pinnedIds[a.id] ? 1 : 0;
            const bPinned = pinnedIds[b.id] ? 1 : 0;
            const aScore = aPinned * 2 + aRunning;
            const bScore = bPinned * 2 + bRunning;
            if (aScore !== bScore) return bScore - aScore;
            return a.name < b.name ? -1 : a.name > b.name ? 1 : 0;
        }
        list.sort(byPriority);
        if (!sameAppList(filteredApps, list)) filteredApps = list;
    }

    onAllAppsChanged: if (pinnedIdsLoaded) buildFilteredList()
    onPinnedIdsChanged: if (appsLoaded) buildFilteredList()
    onRunningSetChanged: if (pinnedIdsLoaded && appsLoaded) buildFilteredList()

    Process {
        id: pinnedLoadProcess
        command: ["sh", "-c", "cat " + launcher.quote(launcher.stateFile) + " 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const ids = {};
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const id = lines[i].trim();
                    if (id !== "") ids[id] = true;
                }
                launcher.pinnedIdsLoaded = true;
                if (!launcher.samePinnedIds(launcher.pinnedIds, ids)) {
                    launcher.pinnedIds = ids;
                } else if (launcher.appsLoaded) {
                    launcher.buildFilteredList();
                }
            }
        }
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            launcher.appsLoaded = false;
            launcher.loadApps();
        }
    }

    Connections {
        target: HyprlandData
        function onWindowListChanged() {
            launcher.updateRunningSet();
        }
    }

    Component.onCompleted: {
        loadApps();
        loadPinnedIds();
        updateRunningSet();
    }

    onVisibleChanged: {
        if (visible) {
            if (!appsLoaded) loadApps();
            updateRunningSet();
            cardOffsetX = 0;
            cardOffsetY = 0;
            Qt.callLater(function() {
                searchField.forceActiveFocus();
                if (Qt.inputMethod) Qt.inputMethod.show();
            });
        } else {
            searchField.text = "";
            if (Qt.inputMethod) Qt.inputMethod.hide();
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: launcher.open = false
    }

    Rectangle {
        id: card
        x: (parent.width - width) / 2 + launcher.cardOffsetX
        y: (parent.height - height) / 2 + launcher.cardOffsetY
        width: Math.min(parent.width * 0.72, 960)
        height: Math.min(parent.height * 0.80, 720)
        color: Appearance.tiling.bg
        radius: Appearance.tiling.dialogRadius
        border.color: Appearance.tiling.border
        border.width: Appearance.tiling.borderWidth
        clip: true

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ─── Titlebar ───
            Rectangle {
                id: titlebar
                Layout.fillWidth: true
                implicitHeight: Appearance.tiling.titlebarHeight
                color: Appearance.tiling.bg
                border.width: 0

                MouseArea {
                    anchors.fill: parent
                    property real pressX: 0
                    property real pressY: 0
                    onPressed: (mouse) => {
                        pressX = mouse.x
                        pressY = mouse.y
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed) {
                            launcher.cardOffsetX += mouse.x - pressX
                            launcher.cardOffsetY += mouse.y - pressY
                        }
                    }
                    cursorShape: Qt.SizeAllCursor
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 6
                    spacing: 6

                    CosmicIcon {
                        name: "actions/application-menu-symbolic"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.tiling.textBright
                    }

                    StyledText {
                        text: "App Launcher"
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.family: Appearance.font.family.monospace
                        color: Appearance.tiling.textBright
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: launcher.filteredApps.length + " apps"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.family: Appearance.font.family.monospace
                        color: Appearance.tiling.textBright
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Appearance.tiling.borderWidth
                    color: Appearance.tiling.border
                }
            }

            // ─── Search bar ───
            Rectangle {
                Layout.preferredWidth: 280
                Layout.preferredHeight: 34
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                Layout.alignment: Qt.AlignHCenter
                color: Appearance.tiling.bgInput
                radius: 20
                border.width: searchField.activeFocus ? 1 : Appearance.tiling.borderWidth
                border.color: searchField.activeFocus ? Appearance.tiling.borderFocus : Appearance.tiling.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    CosmicIcon {
                        name: "actions/system-search-symbolic"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.tiling.textDim
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        StyledText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchField.text === ""
                            text: "Type to search..."
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.family: Appearance.font.family.monospace
                            color: Appearance.tiling.textDim
                        }

                        TextField {
                            id: searchField
                            anchors.fill: parent
                            color: Appearance.tiling.textBright
                            selectionColor: Appearance.tiling.accent
                            selectedTextColor: Appearance.tiling.bg
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.normal
                            verticalAlignment: TextInput.AlignVCenter
                            background: null
                            padding: 0
                            renderType: Text.NativeRendering
                            onTextChanged: launcher.buildFilteredList()
                            Keys.onEscapePressed: launcher.open = false
                            Keys.onReturnPressed: {
                                if (launcher.filteredApps.length > 0) {
                                    launcher.launchApp(launcher.filteredApps[0]);
                                    launcher.open = false;
                                }
                            }
                        }
                    }
                }
            }

            // ─── App grid ───
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                clip: true

                GridView {
                    id: grid
                    anchors.fill: parent
                    anchors.leftMargin: 2
                    anchors.rightMargin: 10

                    cellWidth: 100
                    cellHeight: 104
                    model: launcher.filteredApps
                    clip: true

                    boundsBehavior: Flickable.StopAtBounds
                    boundsMovement: Flickable.StopAtBounds
                    flickDeceleration: 2800
                    maximumFlickVelocity: 5200
                    reuseItems: false

                    delegate: Item {
                        id: appItem
                        width: grid.cellWidth
                        height: grid.cellHeight

                        required property var modelData
                        required property int index

                        property bool isPinned: modelData && !!launcher.pinnedIds[modelData.id]
                        property bool isRunning: modelData && launcher.isAppRunning(modelData)
                        property string resolvedIconSource: modelData ? launcher.iconSource(appItem.modelData.icon) : ""

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: Appearance.tiling.dialogRadius
                            color: ma.containsMouse ? Appearance.tiling.bgHover : "transparent"
                            border.width: ma.containsMouse ? Appearance.tiling.borderWidth : 0
                            border.color: ma.containsMouse ? Appearance.tiling.border : "transparent"
                        }

                        // Pin badge
                        Rectangle {
                            id: pinBadge
                            visible: ma.containsMouse || appItem.isPinned
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 3
                            anchors.rightMargin: 3
                            width: 18; height: 18
                            radius: 9
                            color: appItem.isPinned ? Appearance.tiling.accent : Appearance.tiling.bgActive
                            border.color: appItem.isPinned ? Appearance.tiling.borderFocus : Appearance.tiling.border
                            border.width: Appearance.tiling.borderWidth
                            z: 2

                            CosmicIcon {
                                anchors.centerIn: parent
                                name: "actions/pin-symbolic"
                                iconSize: 11
                                color: appItem.isPinned ? Appearance.tiling.textBright : Appearance.tiling.textDim
                            }
                        }

                        // Icon
                        Item {
                            id: iconWrapper
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 12
                            width: 48; height: 48

                            // Fallback: only show when icon truly doesn't exist
                            Rectangle {
                                visible: appItem.resolvedIconSource === "" || appIcon.status === Image.Error
                                anchors.fill: parent
                                radius: 8
                                color: Appearance.tiling.bgActive
                                border.width: Appearance.tiling.borderWidth
                                border.color: Appearance.tiling.border

                                StyledText {
                                    anchors.centerIn: parent
                                    text: (appItem.modelData && appItem.modelData.name) ? appItem.modelData.name.charAt(0).toUpperCase() : "?"
                                    font.pixelSize: Appearance.font.pixelSize.large
                                    font.family: Appearance.font.family.monospace
                                    font.weight: Font.Bold
                                    color: Appearance.tiling.accentBright
                                }
                            }

                            IconImage {
                                id: appIcon
                                anchors.fill: parent
                                source: appItem.resolvedIconSource
                                implicitSize: 48
                                asynchronous: false
                                mipmap: true
                            }
                        }

                        // Running indicator
                        Rectangle {
                            visible: appItem.isRunning
                            anchors.top: iconWrapper.bottom
                            anchors.topMargin: 3
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 8; height: 8
                            radius: 4
                            color: "#ffc23a"
                            border.color: "#803a2400"
                            border.width: 1
                            z: 1
                        }

                        // Label
                        StyledText {
                            id: appLabel
                            anchors.top: iconWrapper.bottom
                            anchors.topMargin: 14
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            text: appItem.modelData ? appItem.modelData.name : ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.family: Appearance.font.family.monospace
                            color: ma.containsMouse ? Appearance.tiling.textBright : Appearance.tiling.text
                            lineHeight: 1.1
                        }

                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            z: 1
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: {
                                if (containsMouse) {
                                    launcher.focusedAppDescription = appItem.modelData.comment || appItem.modelData.genericName || ""
                                } else if (launcher.focusedAppDescription === (appItem.modelData.comment || appItem.modelData.genericName || "")) {
                                    launcher.focusedAppDescription = ""
                                }
                            }
                            onClicked: (mouse) => {
                                const localPinPos = mapToItem(pinBadge, mouse.x, mouse.y);
                                if (localPinPos.x >= 0 && localPinPos.x <= pinBadge.width &&
                                    localPinPos.y >= 0 && localPinPos.y <= pinBadge.height) {
                                    launcher.togglePinned(appItem.modelData.id);
                                    return;
                                }
                                launcher.launchApp(appItem.modelData);
                                launcher.open = false;
                            }
                        }
                    }
                }

                // Scrollbar
                Rectangle {
                    id: scrollTrack
                    readonly property int columnCount: Math.max(1, Math.floor(grid.width / grid.cellWidth))
                    readonly property int rowCount: Math.ceil(launcher.filteredApps.length / columnCount)
                    readonly property real calculatedContentHeight: Math.max(grid.height, rowCount * grid.cellHeight)
                    readonly property real scrollableHeight: Math.max(0, calculatedContentHeight - grid.height)
                    readonly property real thumbHeight: Math.min(height, Math.max(36, height * grid.height / calculatedContentHeight))
                    readonly property real thumbRange: Math.max(0, height - thumbHeight)

                    visible: scrollableHeight > 1
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    width: 8
                    radius: 4
                    color: Appearance.tiling.bgInput
                    border.width: Appearance.tiling.borderWidth
                    border.color: Appearance.tiling.border

                    MouseArea {
                        anchors.fill: parent
                        onClicked: (mouse) => {
                            const target = Math.max(0, mouse.y - scrollTrack.thumbHeight / 2);
                            grid.contentY = Math.max(0, Math.min(1, target / Math.max(1, scrollTrack.thumbRange))) * scrollTrack.scrollableHeight;
                        }
                    }

                    Rectangle {
                        id: scrollThumb
                        width: parent.width - 2
                        x: 1
                        height: scrollTrack.thumbHeight
                        radius: 3
                        color: thumbDrag.containsMouse || thumbDrag.pressed ? Appearance.tiling.accent : Appearance.tiling.textDim

                        property bool dragging: false

                        Binding on y {
                            when: !scrollThumb.dragging
                            value: scrollTrack.scrollableHeight > 0
                                ? Math.max(0, Math.min(1, grid.contentY / scrollTrack.scrollableHeight)) * scrollTrack.thumbRange
                                : 0
                        }

                        MouseArea {
                            id: thumbDrag
                            anchors.fill: parent
                            hoverEnabled: true
                            drag.target: scrollThumb
                            drag.axis: Drag.YAxis
                            drag.minimumY: 0
                            drag.maximumY: scrollTrack.thumbRange

                            onPressed: scrollThumb.dragging = true
                            onReleased: scrollThumb.dragging = false
                            onCanceled: scrollThumb.dragging = false
                            onPositionChanged: {
                                if (!pressed) return;
                                grid.contentY = Math.max(0, Math.min(1, scrollThumb.y / Math.max(1, scrollTrack.thumbRange))) * scrollTrack.scrollableHeight;
                            }
                        }
                    }
                }
            }

            // ─── Status bar ───
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 22
                color: Appearance.tiling.bg

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Appearance.tiling.borderWidth
                    color: Appearance.tiling.border
                }

                StyledText {
                    anchors.centerIn: parent
                    text: launcher.focusedAppDescription || launcher.filteredApps.length + " apps"
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.family: Appearance.font.family.monospace
                    color: Appearance.tiling.textBright
                    elide: Text.ElideRight
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    IpcHandler {
        target: "appLauncher"

        function toggle(): void {
            launcher.open = !launcher.open;
        }

        function close(): void {
            launcher.open = false;
        }

        function open(): void {
            launcher.open = true;
        }
    }
}
