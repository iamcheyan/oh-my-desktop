# Clipboard Module Reliability

This document describes the clipboard extension at
`~/.local/share/sumika-shell/extensions/clipboard/` and the reliability rules
that must be preserved when it is changed.

## Ownership

The extension owns the clipboard UI, history watcher, paste transport, image
path conversion, and its module actions. The core shell only provides module
discovery, process supervision, IPC, and the shared UI/runtime APIs.

The extension must remain optional: when it is disabled or absent, the core
shell must still start. When it is enabled, its store process is an
application module supervised by `omd-clipboard-store.service`.

## Data Flow

```text
Wayland clipboard owner
        |
        v
one wl-paste --watch process
        |
        v
omd-clipboard-store-event
  1. settle MIME types
  2. read image/* or text payload
  3. reject empty/generated-path payloads
  4. hash and atomically deduplicate
  5. cliphist store
  6. best-effort UI IPC refresh
        |
        v
Cliphist.qml -> ClipboardDialog
```

There must be one watcher only. A separate text watcher and image watcher race
on the same Wayland offer and can classify screenshots as text, miss a new
offer, or overwrite the perceived latest entry.

## Reliability Rules

### MIME classification

The callback may run before a screenshot provider has finished publishing its
MIME list. It waits briefly and prefers `image/*`. If the MIME list is still
unavailable, the event is ignored. Unknown binary data must never be read via
the text protocol and stored as text.

Text is stored only when the offer has a non-empty MIME list and contains a
visible character. Entries containing `/tmp/omd-clip-` are generated paste
transport payloads and are intentionally ignored to prevent feedback loops.

### Deduplication

The decoded payload is hashed. A per-hash lock directory is claimed before
calling `cliphist store`, so duplicate callbacks from one Wayland offer do not
create duplicate history entries or duplicate UI refreshes. Hash markers are
short-lived state under:

```text
${SUMIKA_SHELL_STATE_HOME:-~/.local/state/sumika-shell}/clipboard/hashes/
```

The state directory is mode `0700` and is not part of the repository.

### Process lifecycle

`omd-clipboard-store` supports:

```text
status   report the managed PID or missing dependencies
start    run the watcher foreground
stop     stop only the clipboard daemon recorded by its state protocol
restart  replace the current daemon
repair   ensure a supervised daemon exists
```

`repair` first keeps an existing managed systemd unit, then restarts it when
possible, and can create an `omd-clipboard-store` transient user unit when the
registry has not started one yet. The unit uses `Restart=on-failure` and
`KillMode=mixed`.

The Quickshell stop path must not use a broad `pkill -f 'wl-paste --watch'`:
that can kill unrelated desktop watchers. It resolves the clipboard extension
from the module registry and invokes its `stop` protocol instead.

### UI communication

History refresh IPC is best effort:

```text
qs -p <clipboard-app> ipc call cliphistService update
```

The watcher must not first require a matching UI process. The clipboard UI is
on-demand and may be starting, restarting, or closed. A failed refresh must
never make the storage callback fail.

## Paste Paths

`bin/omd-clipboard-paste` is the single entry point for image-path and smart
paste operations. It decodes one history entry and uses
`omd-paste-at-cursor` for the actual target-window paste.

- Normal text: restore decoded data to the clipboard and paste once.
- Smart paste to a terminal: write an image to `/tmp/omd-clip-<timestamp>.<ext>`,
  put the path in the clipboard, and paste the path once.
- Smart paste to a GUI application: keep an image as an image.
- Explicit “paste image as path”: always use path conversion.

The terminal decision is made from the active Hyprland window class. This is
deliberately separate from the clipboard storage watcher.

## Self-Repair Checklist

When the module is enabled, these checks should pass:

```sh
omd-clipboard-store status
systemctl --user is-active omd-clipboard-store.service
pgrep -af 'wl-paste --watch'
```

There should be one store process and one clipboard watcher. If the service is
missing or stopped, invoke:

```sh
omd-clipboard-store repair
```

The normal shell reload path also stops the old daemon through the module
protocol and starts the registry application again.

## Verification

### Static

```sh
bash -n \
  clipboard/bin/omd-clipboard \
  clipboard/bin/omd-clipboard-store \
  clipboard/bin/omd-clipboard-store-event \
  clipboard/bin/omd-clipboard-paste
```

### Runtime

1. Copy a unique text marker and verify it appears once in `cliphist list`.
2. Publish a PNG clipboard offer and verify a `binary data ... png` entry.
3. Repeat the same offer and verify no duplicate entry is added.
4. Open the clipboard UI repeatedly and verify the same service is reused and
   the UI refreshes without requiring a shell reload.
5. Stop/restart the store service and repeat both text and image tests.
6. Test smart paste in a terminal and a GUI application separately.

## Known Limits

Wayland clipboard data is owned by the active clipboard provider. If that
provider exits before its offer can be read, the event cannot be recovered by
the shell; the callback records and ignores the incomplete event rather than
storing corrupted data. Screenshot tools should keep their clipboard offer
alive long enough for a consumer to read it.

The extension still depends on `wl-paste`, `cliphist`, `file`, and the standard
text-processing commands used by the watcher. `status` reports missing
required commands instead of silently pretending that storage is healthy.
