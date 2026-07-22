# Notification System

Sumika provides a notification server, transient popup UI, and persistent
history. Notification functionality is currently loaded by the bar runtime but
is a candidate for an isolated module in the Core/plugin migration.

## Data Flow

```text
application / notify-send
        -> Quickshell NotificationServer
        -> Notifications singleton
        -> popupList (transient presentation)
        -> list (history and persistence)
```

`quickshell/services/Notifications.qml` owns notification state. It wraps DBus
notifications, starts expiry timers, maintains unread state and application
groups, and emits updates consumed by both popup and history views.

## Behavior

- Transient notifications are removed when their timeout expires.
- Non-transient notifications leave the popup but remain in history.
- A sender-provided positive timeout overrides the configured default.
- A zero timeout is persistent.
- Do Not Disturb inhibits popups without discarding history.
- Popup hover pauses dismissal; leaving resumes it.
- Notification actions, copy, close, grouping, and drag dismissal are handled
  by shared notification widgets.
- Notifications are hidden while the screen is locked.

## Storage And Configuration

History remains runtime cache rather than user configuration:

```text
${XDG_CACHE_HOME:-~/.cache}/quickshell/notifications/notifications.json
```

User settings are under `notifications` in
`~/.config/sumika-shell/sumika.json`, with defaults in
`defaults/config/quickshell/config.json`.

Muted application names are stored one per line in:

```text
~/.config/sumika-shell/notifications/muted_apps.cfg
```

The service migrates the old `~/.config/omd/notifications/muted_apps.cfg`
location when needed. New code must only write the Sumika path.

## UI Surfaces

- `quickshell/modules/notificationPopup/NotificationPopup.qml`: top-right
  transient popup window.
- `quickshell/modules/common/widgets/NotificationListView.qml`: popup list.
- `quickshell/modules/common/widgets/NotificationGroup.qml`: grouping and
  dismissal interaction.
- `quickshell/modules/common/widgets/NotificationItem.qml`: notification row.
- `quickshell/modules/schedulePopup/notifications/TuiNotificationList.qml`:
  persistent history shown from the bar.

Popup placement must use the same top-right margin contract as other bar
panels. Do not add independent hard-coded screen offsets.

## Control Interface

The bar exposes the `notifications` IPC target. `bin/omd-notification-control`
is the supported command wrapper:

```sh
omd-notification-control dismiss-last
omd-notification-control dismiss-all
omd-notification-control toggle-silent
```

New notifications enter through the freedesktop notification protocol (for
example `notify-send`), not through this control IPC.

## Conflict Handling

`quickshell/services/ConflictKiller.qml` disables competing notification
daemons when the Sumika notification server is active. Starting another daemon
such as mako, dunst, or swaync can take the DBus name and prevent Sumika popups.

## Verification

```sh
notify-send 'Sumika test' 'Normal notification'
notify-send -u critical 'Sumika test' 'Critical notification'
```

Verify popup placement and border, timeout behavior, history retention, DND,
actions, muted-app filtering, and behavior while locked.
