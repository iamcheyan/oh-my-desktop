# Sumika Shell Documentation

This directory contains maintained documentation for the current Sumika Shell
implementation and its approved target architecture. Historical work logs,
completed migration reports, one-off incident notes, and superseded proposals
are intentionally not retained.

## Start Here

- [Current repository structure](project-structure.md)
- [Core and extension boundary](architecture/core-extension-boundary.md)
- [Third-party dependencies](architecture/third-party-deps.md)
- [Settings layout contract](settings/settings-layout-system.md)
- [TUI style system](tui/tui-style-system.md)

## Architecture

- [Bar popup height stability](architecture/bar-popup-height-stability.md)
- [Top bar implementation](architecture/topbar-implementation.md)
- [Session persistence](architecture/session-persistence.md)
- [Theme runtime](architecture/omarchy-theme-system.md)
- [Wallpaper runtime](architecture/wallpaper-runtime.md)

## Features

- [Clipboard menu](features/clipboard-menu.md)
- [Smart paste](features/smart-paste.md)
- [Kitty paste integration](features/paste-kitty-conflicts.md)
- [Input method integration](features/input-method-integration.md)
- [Keybindings — 键位逻辑与完整列表](features/keybindings.md)
- [Keyboard remap](features/keyboard-remap.md)
- [Key capture and extended function keys](features/key-capture-and-extended-f-keys.md)
- [Notification system](features/notification-system.md)
- [Overview command palette](features/overview-command-palette.md)
- [Overview workspaces](features/overview-workspaces.md)
- [Screenshot tool](features/screenshot-tool-current-state.md)
- [Voice input](features/voice-input.md)
- [Wi-Fi connection flow](features/wifi-connect-flow.md)
- [Backup TUI](features/backup-tui.md)

## Settings And TUI

- [Settings behavior](settings/settings-center.md)
- [Settings layout system](settings/settings-layout-system.md)
- [TUI tools index](tui/settings-tui-index.md)
- [TUI color mapping](tui/tui-color-mapping-system.md)
- [TUI framework](tui/tui-framework-plan.md)
- [TUI style](tui/tui-style-system.md)
- [Wi-Fi and Bluetooth TUI](tui/wifi-bluetooth-tui.md)

## Platform Notes

- [Asahi Bluetooth keyboard pairing](platform/asahi-bluetooth-keyboard-pairing.md)
- [Asahi notch behavior](platform/asahi-notch.md)
- [GDM Hyprland session](platform/gdm-hyprland-quickshell-session.md)
- [NixOS installation](platform/nixos-install-adaptation.md)

## Maintenance Rules

1. One topic has one authoritative document. Update it instead of adding a new
   report with a date or round number.
2. Architecture documents distinguish current implementation from target
   design. The current ownership contract lives in the Core/extension boundary
   document.
3. Use repository-relative Markdown links.
4. Use the Sumika path API. Do not document new state under
   `~/.local/state/sumika-shell` or user data under the repository symlink.
5. Delete completed audit and incident documents after their durable findings
   have been incorporated into the relevant reference document.
6. A planning document remains only while its migration is active. When the
   work completes, merge stable behavior into reference docs and remove the
   plan.
