# Context-menu keyboard shortcuts

All menus based on `ContextMenuWindow` accept a single letter while open. The
menu takes focus when it opens, so the letter is consumed by the menu and does
not reach the application underneath it. `Escape` closes the menu.

Each `ContextMenuItem` gets a mnemonic from its visible label. The allocator
walks items in visual order and chooses the first unused ASCII letter. Thus
`Save Snapshot` uses `S`, while a later `Shutdown` moves to the next available
letter instead of silently colliding. A menu may reserve a specific letter by
setting `shortcutKey`; invalid or duplicate reservations are treated as
unavailable and automatically reassigned. Items that contain no unused Latin
letter simply have no keyboard hint.

The assigned key is rendered underlined inline in the label, matching the
conventional mnemonic presentation. If the assigned letter is not present in
the label, the row keeps its normal text and the key remains available for
activation without adding a distracting suffix.

Shortcut allocation is local to one menu. Two different menus may use the same
letter because only one menu can be active through `ContextMenuTracker`; a
shortcut must never be registered as a global compositor binding. Visibility
and enabled state are checked both during allocation and activation, so
conditional rows (for example Hibernate) do not steal a key from an item the
user can actually select.

Implementation:

- `quickshell/modules/common/widgets/ContextMenuWindow.qml` collects visible
  `ContextMenuItem` descendants, allocates keys, focuses the popup, and handles
  activation.
- `quickshell/modules/common/widgets/ContextMenuItem.qml` renders the assigned
  hint consistently for core and extension menus.

When adding a menu item, leave `shortcutKey` empty unless a specific mnemonic
is important. If it is set, use one ASCII letter and verify the menu still has
unique visible hints after conditional rows appear.
