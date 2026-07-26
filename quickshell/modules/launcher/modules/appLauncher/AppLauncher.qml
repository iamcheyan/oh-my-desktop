import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import "widgets"

PanelWindow {
    id: launcher
    readonly property bool perfMode: true
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:appLauncher"
    WlrLayershell.keyboardFocus: launcher.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; left: true; right: true; bottom: true }

    visible: launcher.open

    readonly property string stateDir: Quickshell.shellDir + "/.state"
    readonly property string stateFile: stateDir + "/pinned-apps"
    readonly property string cacheFile: `${Quickshell.env("SUMIKA_SHELL_STATE_HOME") ?? Quickshell.env("HOME") + "/.local/state/sumika-shell"}/applauncher/apps.json`
    readonly property string cacheScript: (function() {
        return Directories.root + "/bin/omd-applauncher-cache"
    })()
    property bool open: false
    property real cardOffsetX: 0
    property real cardOffsetY: 0
    property string focusedAppDescription: ""
    readonly property string toolsFile: Directories.root + "/quickshell/modules/launcher/internal-tools.json"
    property var internalTools: []
    property bool toolsLoaded: false

    function run(command) { Quickshell.execDetached(["sh", "-c", command]); }

    function quote(value) {
        return "'" + value.replace(/'/g, "'\\''") + "'";
    }

    function launchApp(desktopEntry) {
        if (!desktopEntry) return;
        if (desktopEntry.id === "omd-tools.desktop") {
            launcher.open = false;
            Quickshell.execDetached([
                Directories.root + "/bin/omd-settings",
                "open", "overview"
            ]);
            return;
        }
        if (desktopEntry._toolCommand && desktopEntry._toolCommand.length > 0) {
            launcher.open = false;
            const cmd = desktopEntry._toolCommand.map(arg => {
                return arg
                    .replace(/\$root/g, Directories.root)
                    .replace(/\$HOME/g, Quickshell.env("HOME") ?? "");
            });
            Quickshell.execDetached(cmd);
            console.log("[AppLauncher] Launched internal tool " + desktopEntry.id);
            return;
        }
        const detach = Directories.root + "/bin/omd-detach";
        const appId = desktopEntry.desktopId || desktopEntry.id || "";
        if (appId.length === 0) return;

        // Let GTK/GIO handle Desktop Entry Exec quoting, field codes, Path, and
        // terminal semantics. Splitting Exec by spaces breaks real-world apps.
        const q = (s) => "'" + s.replace(/'/g, "'\\''") + "'";
        Quickshell.execDetached([
            detach, "sh", "-c",
            "gtk-launch " + q(appId) + " || gio launch " + q(desktopEntry.desktopFile || appId)
        ]);
        console.log("[AppLauncher] Launched desktop entry " + appId);
    }

    function iconSource(icon) {
        if (!icon) return "";
        if (icon.startsWith("nerd:")) return icon;
        if (icon.startsWith("/")) return "file://" + icon;
        const resolved = Quickshell.iconPath(icon, true);
        if (resolved.startsWith("/")) return "file://" + resolved;
        if (resolved) return resolved;
        return "";
    }

    // ── Session action menu (copied from OverviewSearch) ──
    property bool sessionMenuOpen: true

    function requestSessionAction(action, label) {
        launcher.sessionMenuOpen = false;
        const barConfig = Directories.root + "/apps/omd-bar";
        Quickshell.execDetached([
            "qs", "-p", barConfig, "ipc", "call", "session", "confirm", action, label
        ]);
        launcher.open = false;
    }

    function reloadShell() {
        launcher.sessionMenuOpen = false;
        Quickshell.execDetached([
            Directories.root + "/bin/omd-restart"
        ]);
        launcher.open = false;
    }

    property var pinnedIds: ({})
    property var allApps: []
    property var filteredApps: []
    property var runningSet: ({})
    property bool pinnedIdsLoaded: false
    property bool appsLoaded: false
    property bool cacheRebuildRequested: false

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

    function isAppRunning(app) {
        if (!app) return false;
        if (app.id === "omd-tools.desktop") return false;

        const set = launcher.runningSet;
        if (!set) return false;

        const id = (app.id || "").split("/").pop().split(".").pop().toLowerCase();
        const exec = (app.execString || "").split(" ")[0].split("/").pop().toLowerCase();
        const stripped = exec.replace(/-stable$/, "").replace(/-bin$/, "").replace(/^env-/, "");
        const candidates = [id, exec, stripped];
        for (let i = 0; i < candidates.length; i++) {
            const c = candidates[i];
            if (c && set[c]) return true;
        }
        for (const k in set) {
            if (!k) continue;
            if (id && (k === id || k.indexOf(id) >= 0 || id.indexOf(k) >= 0)) return true;
            if (exec && (k === exec || k.indexOf(exec) >= 0 || exec.indexOf(k) >= 0)) return true;
            if (stripped && k === stripped) return true;
        }
        return false;
    }

    function loadPinnedIds() {
        if (pinnedIdsLoaded) return;
        pinnedFileView.reload();
    }

    function loadApps() {
        requestCacheRebuild();
    }

    function requestCacheRebuild() {
        if (cacheRebuildRequested) {
            appsLoaded = true;
            if (pinnedIdsLoaded) buildFilteredList();
            tryOpenOnDemand();
            return;
        }
        cacheRebuildRequested = true;
        cacheRefreshProcess.running = false;
        cacheRefreshProcess.command = [launcher.cacheScript];
        cacheRefreshProcess.running = true;
    }

    function loadAppsFromCache(text) {
        try {
            const cached = JSON.parse(text);
            if (!Array.isArray(cached) || cached.length === 0) return false;
            const apps = cached.map(app => ({
                id: app.id,
                desktopId: app.desktopId || app.id,
                desktopFile: app.desktopFile || "",
                name: app.name,
                icon: app.icon,
                execString: app.exec,
                genericName: app.genericName || "",
                comment: app.comment || "",
                keywords: (app.keywords || "").split(";").filter(k => k.length > 0),
                workingDirectory: app.workingDirectory || ""
            }));
            apps.push({
                id: "omd-tools.desktop",
                desktopId: "omd-tools.desktop",
                name: "OMD Tools",
                icon: "applications-utilities",
                genericName: "Desktop Tools",
                comment: "Open OMD themes and advanced tools",
                keywords: ["tools", "theme", "voice", "keyboard", "windows", "vm", "omd"]
            });
            // Merge internal tools into the desktop app list
            const merged = apps.concat(launcher.internalTools || []);
            if (!sameAppList(allApps, merged)) {
                allApps = merged;
            }
            if (!appsLoaded) {
                appsLoaded = true;
                if (pinnedIdsLoaded) buildFilteredList();
            }
            return true;
        } catch (e) {
            return false;
        }
    }

    function loadToolsFromManifest(text) {
        try {
            const tools = JSON.parse(text);
            if (!Array.isArray(tools) || tools.length === 0) return false;
            const entries = tools.map(t => ({
                id: t.id,
                desktopId: t.id,
                desktopFile: "",
                name: t.name,
                icon: "nerd:" + t.icon,
                execString: "",
                genericName: "",
                comment: t.description || "",
                keywords: t.keywords || [],
                _toolCommand: t.command || []
            }));
            launcher.internalTools = entries;
            return true;
        } catch (e) {
            console.error("[AppLauncher] Failed to parse internal tools manifest:", e);
            return false;
        }
    }

    function mergeInternalTools() {
        if (launcher.internalTools.length === 0) return;
        const merged = allApps.concat(launcher.internalTools);
        if (!sameAppList(allApps, merged)) {
            allApps = merged;
        }
    }

    Process {
        id: cacheRefreshProcess
        onExited: (exitCode, exitStatus) => {
            // Allow the next open to trigger a fresh rebuild.
            launcher.cacheRebuildRequested = false;
            if (exitCode === 0) {
                cacheFileView.reload();
            } else {
                console.error("[AppLauncher] Cache refresh failed with code", exitCode, "and status", exitStatus);
                launcher.appsLoaded = true;
                if (launcher.pinnedIdsLoaded) launcher.buildFilteredList();
                launcher.tryOpenOnDemand();
            }
        }
    }

    // After the launcher UI is fully rendered, silently rebuild the app cache
    // in the background so newly-installed apps appear on the next open
    // (or update the current list if the launcher stays open).
    Timer {
        id: backgroundCacheRefreshTimer
        interval: 800
        repeat: false
        onTriggered: launcher.requestCacheRebuild()
    }

    // In on-demand mode the window opens only when both apps and pinned IDs
    // are ready, so the grid is never shown empty. A 400 ms fallback timer
    // ensures the window always appears even when the cache is missing.
    Timer {
        id: onDemandReadyTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (launcher.onDemand && !launcher.open && !launcher._onDemandOpened) {
                launcher._onDemandOpened = true;
                launcher.open = true;
            }
        }
    }

    property bool _onDemandOpened: false
    function tryOpenOnDemand() {
        if (!onDemand || open || _onDemandOpened) return;
        if (appsLoaded && pinnedIdsLoaded) {
            onDemandReadyTimer.stop();
            _onDemandOpened = true;
            launcher.open = true;
        }
    }

    FileView {
        id: cacheFileView
        path: launcher.cacheFile
        onLoaded: {
            var content = text();
            if (content.length > 0) {
                // If cache parsing fails, rebuild the cache in a background
                // process instead of pulling Quickshell's DesktopEntries model
                // into this cold-start UI process.
                if (!launcher.loadAppsFromCache(content)) {
                    launcher.loadApps();
                }
            } else {
                launcher.loadApps();
            }
            launcher.tryOpenOnDemand();
        }
        onLoadFailed: error => {
            launcher.loadApps();
            launcher.tryOpenOnDemand();
        }
    }


    FileView {
        id: toolsFileView
        path: launcher.toolsFile
        onLoaded: {
            launcher.loadToolsFromManifest(text());
        }
        onLoadFailed: error => {
            console.warn("[AppLauncher] Internal tools manifest not found at", launcher.toolsFile);
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
            const aPinned = pinnedIds[a.id] ? 1 : 0;
            const bPinned = pinnedIds[b.id] ? 1 : 0;
            if (aPinned !== bPinned) return bPinned - aPinned;
            return a.name < b.name ? -1 : a.name > b.name ? 1 : 0;
        }
        list.sort(byPriority);
        if (!sameAppList(filteredApps, list)) filteredApps = list;
    }
    onAllAppsChanged: if (pinnedIdsLoaded) buildFilteredList()
    onPinnedIdsChanged: if (appsLoaded) buildFilteredList()
    onInternalToolsChanged: mergeInternalTools()

    Loader {
        id: runningAppsLoader
        active: false
        asynchronous: true
        source: "RunningApps.qml"
        visible: false
        onLoaded: launcher.runningSet = item.runningSet
    }

    Connections {
        target: runningAppsLoader.item
        enabled: runningAppsLoader.item !== null
        function onRunningSetChanged() {
            launcher.runningSet = runningAppsLoader.item.runningSet;
        }
    }

    Timer {
        id: runningDataDelayTimer
        interval: 220
        repeat: false
        onTriggered: runningAppsLoader.active = true
    }

    FileView {
        id: pinnedFileView
        path: launcher.stateFile
        onLoaded: {
            var content = text();
            const ids = {};
            const lines = content.split("\n");
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
            launcher.tryOpenOnDemand();
        }
        onLoadFailed: error => {
            launcher.pinnedIdsLoaded = true;
            launcher.tryOpenOnDemand();
        }
    }

    readonly property bool onDemand: (Quickshell.env("OMD_APP_ON_DEMAND") ?? "") === "1"

    Component.onCompleted: {
        // Kick off all data loading synchronously before anything renders.
        // In on-demand mode the window stays closed until tryOpenOnDemand()
        // confirms both appsLoaded and pinnedIdsLoaded, eliminating the
        // black-grid flash. The fallback timer opens it after 400 ms worst-case.
        loadPinnedIds();
        if (!appsLoaded) {
            cacheFileView.reload();
        }
        toolsFileView.reload();
        if (onDemand) {
            onDemandReadyTimer.start();
            // If data already loaded (hot-reload), open immediately.
            if (appsLoaded && pinnedIdsLoaded) {
                _onDemandOpened = true;
                launcher.open = true;
            }
        }
    }

    onOpenChanged: {
        if (onDemand && !open) {
            // Keep process alive for instant re-show on next toggle.
            // Just hiding via visible: launcher.open is sufficient.
        }
    }

    onVisibleChanged: {
        if (visible) {
            // Data is pre-loaded in onCompleted; this fallback covers
            // persistent (non-on-demand) mode or repeated opens.
            if (!appsLoaded) {
                cacheFileView.reload();
            }
            cardOffsetX = 0;
            cardOffsetY = 0;
            runningDataDelayTimer.restart();
            // After UI renders, silently refresh cache to pick up newly-installed apps.
            backgroundCacheRefreshTimer.restart();
            Qt.callLater(function() {
                searchField.forceActiveFocus();
                if (Qt.inputMethod) Qt.inputMethod.show();
            });
        } else {
            runningDataDelayTimer.stop();
            backgroundCacheRefreshTimer.stop();
            runningAppsLoader.active = false;
            runningSet = {};
            searchField.text = "";
            launcher.sessionMenuOpen = false;
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
        color: "#0f0f14"
        radius: 18
        border.color: TuiStyle.shellBorder
        border.width: TuiStyle.borderWidth
        clip: true

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ─── Titlebar ───
            Rectangle {
                id: titlebar
                Layout.fillWidth: true
                implicitHeight: 44
                color: "transparent"
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

                    StyledText {
                        text: "App Launcher"
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.family: Appearance.font.family.main
                        color: TuiStyle.fg
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: 280
                        Layout.preferredHeight: 34
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        color: "#181818"
                        radius: TuiStyle.radius
                        border.width: 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            StyledText {
                                text: "/"
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.family: Appearance.font.family.main
                                color: TuiStyle.dim
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
                                    font.family: Appearance.font.family.main
                                    color: TuiStyle.dim
                                }

                                TextInput {
                                    id: searchField
                                    anchors.fill: parent
                                    color: TuiStyle.fg
                                    selectionColor: TuiStyle.accent
                                    selectedTextColor: TuiStyle.bg
                                    font.family: Appearance.font.family.main
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    verticalAlignment: TextInput.AlignVCenter
                                    renderType: Text.NativeRendering
                                    onTextChanged: launcher.buildFilteredList()
                                    Keys.onEscapePressed: {
                                        if (launcher.sessionMenuOpen)
                                            launcher.sessionMenuOpen = false;
                                        else
                                            launcher.open = false;
                                    }
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

                    Rectangle {
                        id: sessionMenuButton
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        color: sessionMenuMouse.containsMouse || launcher.sessionMenuOpen ? "#2a2a2a" : "#181818"
                        radius: TuiStyle.radius
                        border.width: 0

                        StyledText {
                            anchors.centerIn: parent
                            text: "\uF0C9"
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.family: Appearance.font.family.iconNerd
                            color: launcher.sessionMenuOpen ? TuiStyle.accent : TuiStyle.fg
                        }

                        MouseArea {
                            id: sessionMenuMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: launcher.sessionMenuOpen = !launcher.sessionMenuOpen
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: TuiStyle.line
                    opacity: 0.35
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
                    reuseItems: launcher.perfMode

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
                            radius: TuiStyle.radius
                            color: "transparent"
                            border.width: 0
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
                            color: appItem.isPinned ? TuiStyle.accent : "#222222"
                            border.width: 0
                            z: 2

                            NerdIcon {
                                anchors.centerIn: parent
                                iconSize: 12
                                text: NerdIconMap.pushPin
                                color: appItem.isPinned ? TuiStyle.bg : TuiStyle.dim
                            }
                        }

                        // Icon
                        Item {
                            id: iconWrapper
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 12
                            width: 48; height: 48

                            readonly property bool isNerdIcon: appItem.resolvedIconSource.startsWith("nerd:")

                            // Nerd Font icon (internal tools) — dark circle with border
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: "#222222"
                                border.width: 2
                                border.color: "#444444"
                                visible: iconWrapper.isNerdIcon

                                NerdIcon {
                                    anchors.centerIn: parent
                                    iconSize: 30
                                    text: {
                                        if (!appItem.resolvedIconSource || !appItem.resolvedIconSource.startsWith("nerd:")) return "";
                                        const prop = appItem.resolvedIconSource.substring(5);
                                        return NerdIconMap[prop] || "";
                                    }
                                    color: "#eeeeee"
                                }
                            }

                            // Desktop icon file
                            IconImage {
                                id: appIcon
                                anchors.fill: parent
                                source: appItem.resolvedIconSource
                                implicitSize: 48
                                asynchronous: true
                                mipmap: true
                                visible: !iconWrapper.isNerdIcon
                            }

                            // Fallback letter (desktop icons only, when icon missing)
                            Rectangle {
                                visible: !iconWrapper.isNerdIcon && (appItem.resolvedIconSource === "" || appIcon.status === Image.Error)
                                anchors.fill: parent
                                radius: 8
                                color: "#222222"
                                border.width: 0

                                StyledText {
                                    anchors.centerIn: parent
                                    text: (appItem.modelData && appItem.modelData.name) ? appItem.modelData.name.charAt(0).toUpperCase() : "?"
                                    font.pixelSize: Appearance.font.pixelSize.large
                                    font.family: Appearance.font.family.main
                                    font.weight: Font.DemiBold
                                    color: TuiStyle.fg
                                }
                            }

                            // Hover tint overlay
                            Rectangle {
                                anchors.fill: parent
                                radius: iconWrapper.isNerdIcon ? width / 2 : 8
                                color: ma.containsMouse ? "#ffffff" : "transparent"
                                opacity: ma.containsMouse ? 0.15 : 0
                                visible: ma.containsMouse
                            }
                        }

                        Rectangle {
                            anchors.top: iconWrapper.bottom
                            anchors.topMargin: 3
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 8; height: 8
                            radius: 4
                            color: "#ffc23a"
                            border.color: "#803a2400"
                            border.width: 1
                            opacity: appItem.isRunning ? 1 : 0
                            z: 1

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 160
                                    easing.type: Easing.OutCubic
                                }
                            }
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
                            font.family: Appearance.font.family.main
                            color: ma.containsMouse ? TuiStyle.fg : TuiStyle.dim
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
                    color: "transparent"
                    border.width: 0

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
                        color: thumbDrag.containsMouse || thumbDrag.pressed ? TuiStyle.accent : TuiStyle.dim

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
                color: "transparent"

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: TuiStyle.line
                    opacity: 0.35
                }

                StyledText {
                    anchors.centerIn: parent
                    text: launcher.focusedAppDescription || launcher.filteredApps.length + " apps"
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.family: Appearance.font.family.main
                    color: TuiStyle.fg
                    elide: Text.ElideRight
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // Modal layer is a sibling of the content layout, so opening the menu
        // never participates in GridView sizing or delegate positioning.
        MouseArea {
            anchors.fill: parent
            z: 50
            visible: launcher.sessionMenuOpen
            onClicked: launcher.sessionMenuOpen = false
        }

        StyledRectangularShadow {
            target: sessionMenu
            visible: launcher.sessionMenuOpen
        }

        Rectangle {
            id: sessionMenu
            z: 51
            visible: launcher.sessionMenuOpen
            anchors {
                top: parent.top
                topMargin: 44
                right: parent.right
                rightMargin: 8
            }
            implicitWidth: sessionMenuColumn.implicitWidth + 8
            implicitHeight: sessionMenuColumn.implicitHeight + 8
            color: TuiStyle.bg
            radius: TuiStyle.shellRadius
            border.width: TuiStyle.borderWidth
            border.color: TuiStyle.menuBorder
            clip: true

            ColumnLayout {
                id: sessionMenuColumn
                anchors.fill: parent
                anchors.margins: 4
                spacing: 0

                ContextMenuItem {
                    nerdIcon: NerdIconMap.archive
                    labelText: "Save Snapshot"
                    onClicked: {
                        launcher.sessionMenuOpen = false;
                        Quickshell.execDetached([`${Directories.root}/bin/omd-session`, "save"]);
                    }
                }

                ContextMenuItem {
                    nerdIcon: NerdIconMap.unarchive
                    labelText: "Restore Snapshot"
                    onClicked: {
                        launcher.sessionMenuOpen = false;
                        Quickshell.execDetached(["bash", "-c",
                            `clients=$(hyprctl -j clients | jq 'length') && ` +
                            `if [ "$clients" -gt 0 ]; then ` +
                            `echo "Workspace not empty ($clients windows) — restore cancelled"; ` +
                            `else ${Directories.root}/bin/omd-session restore; fi`
                        ]);
                    }
                }

                ContextMenuSeparator {}

                ContextMenuItem {
                    nerdIcon: NerdIconMap.logout
                    labelText: "Logout"
                    onClicked: {
                        launcher.sessionMenuOpen = false;
                        launcher.requestSessionAction("logout", "Logout");
                    }
                }

                ContextMenuItem {
                    nerdIcon: NerdIconMap.restart
                    labelText: "Reboot"
                    onClicked: {
                        launcher.sessionMenuOpen = false;
                        launcher.requestSessionAction("reboot", "Reboot");
                    }
                }

                ContextMenuItem {
                    nerdIcon: NerdIconMap.powerSettingsNew
                    labelText: "Shutdown"
                    onClicked: {
                        launcher.sessionMenuOpen = false;
                        launcher.requestSessionAction("poweroff", "Shutdown");
                    }
                }

                ContextMenuSeparator {}

                ContextMenuItem {
                    nerdIcon: NerdIconMap.refresh
                    labelText: "Reload Shell"
                    onClicked: {
                        launcher.sessionMenuOpen = false;
                        launcher.reloadShell();
                    }
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
