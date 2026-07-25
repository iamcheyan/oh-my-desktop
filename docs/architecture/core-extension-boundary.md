# Sumika Core / Extension Boundary

This document records the boundary that is implemented by the current
runtime. It is the acceptance reference for future module changes.

## Core

Core modules live in `quickshell/modules/` and are part of the minimum usable
desktop. They are discovered before extensions and remain available when the
optional module switch is disabled.

Current Core product floor:

`audio`, `clock`, `display`, `launcher`, `notification-popup`, `overview`,
`power-indicator`, `settings`, `systray`, `wifi`, and `workspaces`.

The canonical module ID is the `id` in `module.json`. The directory name may
also be a QML package name when the ID contains characters that are not useful
in a QML import path. For example:

```text
manifest id: notification-popup
directory:  quickshell/modules/notificationPopup/
QML name:   qs.modules.notificationPopup
```

Do not infer module ownership from a filesystem path.

Core services are explicit providers registered by
`quickshell/core/runtime/ServiceManager.qml` and backed by
`quickshell/services/`. A manifest `contributes.services` entry is not a
provider by itself. It must not be used as a placeholder or as a claim that a
service exists.

## Extensions

Optional extensions are installed below:

```text
~/.local/share/sumika-shell/extensions/<id>/
```

The current installed extensions are `clipboard`, `input-method`, `screenshot`,
and `voice`. Each extension owns its QML, application entry points, helpers,
and any module-local service files. It must remain functional when copied to a
different machine with the same public Core API.

The startup registry records `source: "core"` or `source: "extension"` on
modules and UI contributions. Core is loaded first and wins duplicate IDs.
Popup singleton precedence uses this explicit source field, never a repository
path or symlink layout.

## Allowed dependency direction

```text
Extension UI / extension-local service
                 |
                 +--> Core public QML modules and widgets
                 +--> Core ServiceManager / qs.services
                 +--> Core actions and extension points

Core -X-> extension namespaces, extension paths, or extension-owned services
```

An extension may import Core packages such as `qs.modules.common`,
`qs.modules.common.widgets`, `qs.modules.bar`, and `qs.services`. Core must not
import `qs.modules.voice`, `qs.modules.clipboard`, `qs.modules.inputMethod`,
`qs.modules.screenshot`, or any path under the user's extension directory.

## Ownership rules

- Core owns layout, lifecycle, public extension points, and the minimum desktop.
- An extension owns its optional feature UI and its private implementation.
- A Core widget may be consumed by an extension, but an extension must not
  mutate Core singleton state except through a documented API.
- A missing, invalid, or unloaded extension must not prevent Core startup.
- A new service provider must be registered explicitly through the Service API;
  adding a string to a manifest is insufficient.
- QML package aliases are generated only in the runtime import directory. The
  source tree must not receive generated aliases or symlinks.

## Verification

From the repository root:

```sh
./bin/omd-module-validate --all
for f in ~/.local/share/sumika-shell/extensions/*/module.json; do
  ./bin/omd-module-validate "$f"
done
bash -n quickshell/scripts/quickshell bin/omd-modules
omd-modules list
omd-modules info notification-popup
```

The last command deliberately uses the manifest ID and verifies that IDs and
QML-safe directory names are resolved separately.
