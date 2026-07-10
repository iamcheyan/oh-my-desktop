# Notification Redesign

## Goal

Notifications should feel like part of the current OMD TUI shell instead of a
separate legacy surface. The notification center lives under the top bar power
/ battery entry, so power state and attention state are handled from one quiet
system panel.

## Structure

1. Clicking the top bar battery / power icon opens the existing bar popup.
2. The popup keeps the current power summary and session controls.
3. A Notifications section is embedded below the power controls.
4. Toast popups keep using the notification popup process, but use the same
   compact dark TUI styling and appear below the top bar.

## Notification Center

- Width follows the existing bar popup width.
- Header shows unread/total count.
- Header actions:
  - DND toggle.
  - Mark read.
  - Clear all.
- Empty state is compact and visually quiet.
- List rows are dense but readable:
  - app name, summary, relative time, action count
  - body preview, expanding to multiple lines
  - close/copy/action buttons when expanded
- Critical notifications use a thin danger accent, not a large colored card.

## Toasts

- Toasts stay transient and non-focus-stealing.
- Hover pauses timeout through the existing notification group behavior.
- Toasts appear below the top bar on top-bar layouts.
- DND suppresses toast popups but still records notifications in history.

## State Model

- `Notifications.list` remains the source of history.
- `Notifications.popupList` remains the source of active toasts.
- Opening the power / notification panel can mark notifications read.
- DND maps to `Notifications.silent`.
- `discardAllNotifications()` clears history.
- `timeoutAll()` only clears active toasts.

## Visual Rules

- Use `TuiStyle` tokens only.
- No nested cards.
- Cards and rows use small radii and restrained borders.
- Text stays compact; body previews should not push the popup wider.
