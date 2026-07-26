pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import qs
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

/**
 * Provides extra features not in Quickshell.Services.Notifications:
 *  - Persistent storage
 *  - Popup notifications, with timeout
 *  - Notification groups by app
 */
Singleton {
	id: root
    component Notif: QtObject {
        id: wrapper
        required property int notificationId // Could just be `id` but it conflicts with the default prop in QtObject
        property Notification notification
        property list<var> actions: notification?.actions?.map((action) => ({
            "identifier": action.identifier,
            "text": action.text,
        })) ?? []
        property bool popup: false
        property bool isTransient: notification?.hints.transient ?? false
        property string appIcon: notification?.appIcon ?? ""
        property string appName: notification?.appName ?? ""
        property string body: notification?.body ?? ""
        property string image: notification?.image ?? ""
        property string summary: notification?.summary ?? ""
        property double time
        property string urgency: notification?.urgency.toString() ?? "normal"
        property Timer timer

        onNotificationChanged: {
            if (notification === null) {
                root.discardNotification(notificationId);
            }
        }
    }

    function notifToJSON(notif) {
        return {
            "notificationId": notif.notificationId,
            "actions": notif.actions,
            "appIcon": notif.appIcon,
            "appName": notif.appName,
            "body": notif.body,
            "image": notif.image,
            "summary": notif.summary,
            "time": notif.time,
            "urgency": notif.urgency,
        }
    }
    function notifToString(notif) {
        return JSON.stringify(notifToJSON(notif), null, 2);
    }

    component NotifTimer: Timer {
        required property int notificationId
        interval: 7000
        running: true
        onTriggered: () => {
            const index = root.list.findIndex((notif) => notif.notificationId === notificationId);
            const notifObject = root.list[index];
            print("[Notifications] Notification timer triggered for ID: " + notificationId + ", transient: " + notifObject?.isTransient);
            if (notifObject.isTransient) root.discardNotification(notificationId);
            else root.timeoutNotification(notificationId);
            destroy()
        }
    }

    readonly property bool silent: Config.options?.notifications?.silent ?? false
    property var mutedApps: Config.options?.notifications?.mutedApps ?? []
    // Sumika Shell config home (XDG-compliant, matches lib/paths.sh default)
    readonly property string sumikaConfigHome: `${FileUtils.trimFileProtocol(Directories.config)}/sumika-shell`
    // Canonical write path (new location)
    property string mutedAppsFilePath: `${sumikaConfigHome}/notifications/muted_apps.cfg`
    // Legacy read fallback (old location, removed in Phase 7)
    readonly property string mutedAppsFilePathLegacy: `${FileUtils.trimFileProtocol(Directories.config)}/omd/notifications/muted_apps.cfg`
    property bool openMutedEditorAfterWrite: false
    property int unread: 0
    property var filePath: Directories.notificationsPath
    property list<Notif> list: []
    property var popupList: list.filter((notif) => notif.popup && !root.isMuted(notif.appName, notif.summary, notif.body));
    property bool popupInhibited: silent
    property var latestTimeForApp: ({})
    Component {
        id: notifComponent
        Notif {}
    }
    Component {
        id: notifTimerComponent
        NotifTimer {}
    }

    function stringifyList(list) {
        return JSON.stringify(list.map((notif) => notifToJSON(notif)), null, 2);
    }

    // Debounced persistence: writing the whole list to disk on every
    // notification add/discard caused O(n) JSON.stringify + file writes on
    // each event. Coalesce them into a single write after 500ms of quiet.
    Timer {
        id: persistTimer
        interval: 500
        repeat: false
        onTriggered: notifFileView.setText(stringifyList(root.list))
    }
    function schedulePersist() {
        persistTimer.restart()
    }

    // Incrementally maintain latestTimeForApp instead of rebuilding it from
    // the full list on every listChanged.
    function trackLatestTime(notif) {
        const cur = root.latestTimeForApp[notif.appName] || 0;
        if (notif.time > cur) {
            const next = ({});
            Object.assign(next, root.latestTimeForApp);
            next[notif.appName] = notif.time;
            root.latestTimeForApp = next;
        }
    }
    function untrackAppIfStale(appName) {
        if (!root.list.some((notif) => notif.appName === appName)) {
            const next = ({});
            Object.assign(next, root.latestTimeForApp);
            delete next[appName];
            root.latestTimeForApp = next;
        }
    }

    function appNameListForGroups(groups) {
        return Object.keys(groups).sort((a, b) => {
            // Sort by time, descending
            return groups[b].time - groups[a].time;
        });
    }

    function groupsForList(list) {
        const groups = {};
        list.forEach((notif) => {
            if (!groups[notif.appName]) {
                groups[notif.appName] = {
                    appName: notif.appName,
                    appIcon: notif.appIcon,
                    notifications: [],
                    time: 0
                };
            }
            groups[notif.appName].notifications.push(notif);
            // Always set to the latest time in the group
            groups[notif.appName].time = latestTimeForApp[notif.appName] || notif.time;
        });
        return groups;
    }

    property var groupsByAppName: groupsForList(root.list)
    property var popupGroupsByAppName: groupsForList(root.popupList)
    property list<string> appNameList: appNameListForGroups(root.groupsByAppName)
    property list<string> popupAppNameList: appNameListForGroups(root.popupGroupsByAppName)

    // Quickshell's notification IDs starts at 1 on each run, while saved notifications
    // can already contain higher IDs. This is for avoiding id collisions
    property int idOffset
    signal initDone();
    signal notify(notification: var);
    signal discard(id: int);
    signal discardAll();
    signal timeout(id: var);

    function handleNotification(notification) {
        notification.tracked = true
        const newNotifObject = notifComponent.createObject(root, {
            "notificationId": notification.id + root.idOffset,
            "notification": notification,
            "time": Date.now(),
        });
        root.list = [...root.list, newNotifObject];
        root.trackLatestTime(newNotifObject);

        // Popup
        if (!root.popupInhibited && !root.isMuted(newNotifObject.appName, newNotifObject.summary, newNotifObject.body)) {
            newNotifObject.popup = true;
            if (notification.expireTimeout != 0) {
                newNotifObject.timer = notifTimerComponent.createObject(root, {
                    "notificationId": newNotifObject.notificationId,
                    "interval": notification.expireTimeout < 0 ? (Config?.options.notifications.timeout ?? 7000) : notification.expireTimeout,
                });
            }
        }
        root.unread++;
        root.notify(newNotifObject);
        root.schedulePersist();
    }

    function markAllRead() {
        root.unread = 0;
    }

    function toggleSilent() {
        if (Config.options && Config.options.notifications) {
            Config.options.notifications.silent = !Config.options.notifications.silent;
        }
    }

    function isMuted(appName, summary, body) {
        if (!appName) appName = "";
        if (!summary) summary = "";
        if (!body) body = "";

        for (let i = 0; i < root.mutedApps.length; i++) {
            const rule = root.mutedApps[i];
            if (!rule) continue;

            const firstColon = rule.indexOf(":");
            if (firstColon === -1) {
                // Form 0: Simple appName match
                if (rule === appName) {
                    return true;
                }
            } else {
                const secondColon = rule.indexOf(":", firstColon + 1);
                if (secondColon === -1) {
                    // Form 1: appName:summary
                    const ruleApp = rule.substring(0, firstColon);
                    const ruleSummary = rule.substring(firstColon + 1);
                    
                    const appMatch = (ruleApp === "" || ruleApp === "*" || ruleApp === appName);
                    const summaryMatch = summary.toLowerCase().includes(ruleSummary.toLowerCase());
                    
                    if (appMatch && summaryMatch) {
                        return true;
                    }
                } else if (secondColon === firstColon + 1) {
                    // Form 2: appName::body
                    const ruleApp = rule.substring(0, firstColon);
                    const ruleBody = rule.substring(secondColon + 1);
                    
                    const appMatch = (ruleApp === "" || ruleApp === "*" || ruleApp === appName);
                    const bodyMatch = body.toLowerCase().includes(ruleBody.toLowerCase());
                    
                    if (appMatch && bodyMatch) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    function toggleMuteApp(appName, summary) {
        if (!Config.options || !Config.options.notifications)
            return;
        const genericApps = ["notify-send", "swaync", "dunstify", "mako", "notification", ""];
        let rule = appName || "";
        if (summary && genericApps.indexOf(rule) >= 0) {
            rule = rule + ":" + summary.trim();
        }
        const list = [...root.mutedApps];
        const idx = list.indexOf(rule);
        if (idx >= 0)
            list.splice(idx, 1);
        else
            list.push(rule);
        root.mutedApps = list;
        Config.options.notifications.mutedApps = list;
        root.writeMutedAppsFile();
    }

    function setMutedApps(apps) {
        const normalized = [...new Set(apps.map(app => String(app).trim()).filter(app => app.length > 0))];
        root.mutedApps = normalized;
        if (Config.options && Config.options.notifications)
            Config.options.notifications.mutedApps = normalized;
    }

    function openMutedAppsEditor() {
        root.openMutedEditorAfterWrite = true;
        if (!writeMutedFile.running)
            root.writeMutedAppsFile();
    }

    function writeMutedAppsFile() {
        const text = root.mutedApps.length > 0 ? root.mutedApps.join("\n") + "\n" : "";
        writeMutedFile.command = [
            "bash", "-c",
            `mkdir -p "$(dirname "$2")" && printf '%s' "$1" > "$2"`,
            "omd-muted-apps-write", text, root.mutedAppsFilePath
        ];
        writeMutedFile.running = true;
    }

    Process {
        id: writeMutedFile
        running: false
        onExited: {
            if (!root.openMutedEditorAfterWrite)
                return;
            root.openMutedEditorAfterWrite = false;
            editMutedAppsProc.command = [
                "bash", "-c",
                `if command -v xdg-terminal-exec >/dev/null 2>&1; then exec xdg-terminal-exec --app-id=org.omd.edit-muted-apps --title="Muted notification apps" -- vi "$1"; elif command -v foot >/dev/null 2>&1; then exec foot --app-id=org.omd.edit-muted-apps --title="Muted notification apps" -e vi "$1"; else exec kitty --class=org.omd.edit-muted-apps --title="Muted notification apps" -- vi "$1"; fi`,
                "omd-muted-apps-editor", root.mutedAppsFilePath
            ];
            editMutedAppsProc.running = true;
        }
    }

    Process {
        id: editMutedAppsProc
        running: false
        onExited: readMutedAppsProc.running = true
    }

    Process {
        id: readMutedAppsProc
        command: ["bash", "-c", `cat "$1" 2>/dev/null || cat "$2" 2>/dev/null || true`, "omd-muted-apps-read", root.mutedAppsFilePath, root.mutedAppsFilePathLegacy]
        running: false
        stdout: StdioCollector {
            id: mutedAppsCollector
            onStreamFinished: {
                const text = mutedAppsCollector.text.trim();
                root.setMutedApps(text.length > 0 ? text.split("\n") : []);
            }
        }
    }

    function discardLatestNotification() {
        if (root.list.length === 0)
            return;
        root.discardNotification(root.list[root.list.length - 1].notificationId);
    }

    function discardNotification(id) {
        console.log("[Notifications] Discarding notification with ID: " + id);
        const index = root.list.findIndex((notif) => notif.notificationId === id);
        let discardedAppName = null;
        let serverNotif = null;
        if (index !== -1) {
            discardedAppName = root.list[index]?.appName ?? null;
            serverNotif = root.list[index]?.notification ?? null;
            root.list.splice(index, 1);
            triggerListChange()
            root.schedulePersist();
        }
        if (discardedAppName !== null) {
            root.untrackAppIfStale(discardedAppName);
        }
        if (serverNotif !== null) {
            serverNotif.dismiss()
        }
        root.discard(id); // Emit signal
    }
    
    function discardAllNotifications() {
        const serverNotifs = root.list.map((notif) => notif.notification).filter((n) => n !== null);
        root.list = []
        root.latestTimeForApp = ({})
        triggerListChange()
        root.schedulePersist();
        serverNotifs.forEach((notif) => { notif.dismiss() })
        root.discardAll();
    }
    
    function attemptInvokeAction(id, notifIdentifier) {
        console.log("[Notifications] Attempting to invoke action with identifier: " + notifIdentifier + " for notification ID: " + id);
        const entry = root.list.find((notif) => notif.notificationId === id);
        const serverNotif = entry?.notification ?? null;
        if (serverNotif !== null) {
            const action = serverNotif.actions.find((action) => action.identifier === notifIdentifier);
            if (action) {
                action.invoke()
            } else {
                console.log("Action not found: " + notifIdentifier)
            }
        } else {
            console.log("Notification not found in server: " + id)
        }
        root.discardNotification(id);
    }


    function cancelTimeout(id) {
        const index = root.list.findIndex((notif) => notif.notificationId === id);
        if (root.list[index] != null)
            root.list[index].timer.stop();
    }

    function timeoutNotification(id) {
        const index = root.list.findIndex((notif) => notif.notificationId === id);
        if (root.list[index] != null)
            root.list[index].popup = false;
        root.timeout(id);
    }

    function timeoutAll() {
        root.popupList.forEach((notif) => {
            root.timeout(notif.notificationId);
        })
        root.popupList.forEach((notif) => {
            notif.popup = false;
        });
    }


    function triggerListChange() {
        root.list = root.list.slice(0)
    }

    function refresh() {
        notifFileView.reload()
    }

    Component.onCompleted: {
        root.writeMutedAppsFile();
        refresh()
    }

    FileView {
        id: notifFileView
        path: Qt.resolvedUrl(filePath)
        onLoaded: {
            const fileContents = notifFileView.text()
            root.list = JSON.parse(fileContents).map((notif) => {
                return notifComponent.createObject(root, {
                    "notificationId": notif.notificationId,
                    "actions": [], // Notification actions are meaningless if they're not tracked by the server or the sender is dead
                    "appIcon": notif.appIcon,
                    "appName": notif.appName,
                    "body": notif.body,
                    "image": notif.image,
                    "summary": notif.summary,
                    "time": notif.time,
                    "urgency": notif.urgency,
                });
            });
            // Find largest notificationId
            let maxId = 0
            root.list.forEach((notif) => {
                maxId = Math.max(maxId, notif.notificationId)
            })

            console.log("[Notifications] File loaded")
            root.idOffset = maxId
            root.initDone()
        }
        onLoadFailed: (error) => {
            if(error == FileViewError.FileNotFound) {
                console.log("[Notifications] File not found, creating new file.")
                root.list = []
                notifFileView.setText(stringifyList(root.list));
            } else {
                console.log("[Notifications] Error loading file: " + error)
            }
        }
    }
}
