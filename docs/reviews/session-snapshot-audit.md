# Session Snapshot System — Audit

Audit of the Sumika session snapshot/restore system (`bin/sumika-session`,
the QML restore chain, the systemd save-on-exit fallback, and the logout
scripts). Covers bugs, contract mismatches, and redundant code found on
2026-08-11. Each finding has a severity, location, and fix.

## Contract (user intent)

When the "Save current session" checkbox is checked at shutdown, the full
desktop snapshot saves automatically and restores automatically on next boot
without manual intervention. When unchecked, no restore should happen. An
empty desktop (all windows closed) at shutdown must not arm a restore.

## Files

| Role | Path |
|---|---|
| Engine | `bin/sumika-session` |
| Boot auto-restore | `quickshell/modules/powerIndicator/SessionAutoRestore.qml` |
| Restore overlay | `quickshell/modules/powerIndicator/SessionRestoreOverlay.qml` |
| Save checkbox | `quickshell/modules/bar/BarStatusPopup.qml` |
| Power actions | `quickshell/modules/common/functions/Session.qml` |
| Right-click menu | `quickshell/modules/common/widgets/PowerContextMenu.qml` |
| Builtin actions | `quickshell/core/runtime/ActionManager.qml` |
| Logout script | `share/bin/omarchy-system-logout` |
| Save-on-exit unit | `share/systemd/sumika-session-save.service` |
| Unit setup | `bin/sumika-restart` (ensure_session_save_unit) |
| Design doc | `docs/architecture/session-persistence.md` |

## Findings

### A. Contract bugs

#### A1 — Unchecking the box does not disable restore [bug, contract-breaking]

`share/systemd/sumika-session-save.service:29` (ExecStop) and
`share/bin/omarchy-system-logout:8` both run `save-auto-if-stale`
**unconditionally** on every session end, regardless of the checkbox.
`ActionManager.qml:312-330` hardcodes `save-auto-if-stale &&` for
reboot/shutdown/suspend/hibernate. The checkbox in `BarStatusPopup.qml:327`
gates only the `Session.qml` prefix, but the fallback paths arm the marker
anyway. The checkbox is effectively cosmetic.

**Fix:** the checkbox path writes a `save-requested` flag file; the fallback
(`save-auto-if-stale` from systemd/logout) only arms the marker when that flag
exists. Without the flag, an empty save unlinks the marker (per the design
doc). This makes unchecked ⇒ no restore, as intended.

#### A2 — Empty shutdown restores the previous snapshot [bug, wrong trigger]

When `save()` finds no clients (all windows closed, or compositor already
gone at teardown), it returns None. The previous fix armed the marker against
the stale `last.json` (`source: "stale"`), which restores apps the user
already closed. This contradicts
`docs/architecture/session-persistence.md:81-85`, which says an empty save
must remove the marker.

**Fix:** revert the stale-arm. Empty save unlinks the marker. The teardown
race (original problem 1) is handled by the `save-requested` flag + keeping
the last good `last.json` intact (save does not overwrite it on empty).

#### A3 — Skipped restore leaves the marker armed [bug, stale restore]

`SessionAutoRestore.qml:85-87` skips restore when `openWindows > 0` (a
Quickshell reload with apps open) but does **not** consume the marker. Only
`restore-auto` unlinks it (`bin/sumika-session:1837-1840`). A later cold boot
then restores a possibly days-old snapshot. No `savedAt` age gate exists
anywhere in QML.

**Fix:** consume (unlink) the marker whenever the boot check skips restore,
and add a `savedAt` age gate so a marker older than a threshold is ignored.

#### A4 — Failing window-count tool reads as 0 [bug, weak fail-safe]

`SessionAutoRestore.qml:84`: `parseInt("")||0` → 0 when `hyprctl` exists but
emits nothing (broken/tearing down). The `-1` fail-safe only covers missing
tools, not failing ones. Restore then proceeds into a desktop that cannot be
proven empty.

**Fix:** treat empty/whitespace output as `-1`.

### B. Redundant / dead code

#### B1 — ActionManager `.save` variants are byte-identical duplicates [redundant]

`ActionManager.qml:332-345`: `session.logout.save`, `session.reboot.save`,
`session.shutdown.save` are identical to their non-`.save` twins (both run
`save-auto-if-stale && ...`). Delete the three `.save` registrations.

#### B2 — Duplicate restore-empty guard [redundant, drifted]

`PowerContextMenu.qml:36-51` vs `AppLauncher.qml:1078-1092`. AppLauncher's
copy lacks the labwc/pgrep fallback and `|| echo 0`; on labwc `clients` is
empty → `-gt 0` fails → restore runs on a non-empty desktop. Merge into one
`Session.qml` helper.

#### B3 — Double JSON parse of status output [redundant]

`SessionAutoRestore.qml:47-49` then again at `97`. Store the parsed object on
a root property and reuse.

#### B4 — Stale `__pycache__` pyc [dead]

`bin/__pycache__/sumika-sessioncpython-314.pyc` (94KB). `.gitignore` already
covers `__pycache__/`, so it is untracked, but it should not sit in the repo
working tree. Remove it.

#### B5 — Drifted docs [dead, doc drift]

`docs/architecture/session-persistence.md` describes a removed `SessionButton`
topbar module and a `save-close` confirmation popup that no longer exist.
`docs/quickshell-entrypoint-refactor-verification.md` references a
`SessionConfirmOverlay` that does not exist (the confirm UI is the second
`PanelWindow` in `BarStatusPopup.qml`). Update.

### C. Python engine issues

#### C1 — `save()` overwrites last.json with a smaller capture [bug, data loss]

`save_auto_if_stale:926` → `save_auto()` → `save()`. When the marker is absent
and the snapshot is stale, `save()` re-captures and overwrites `last.json`. If
some windows already closed at teardown, the new capture has fewer windows
and the good snapshot only lands in `.bak`. `load_snapshot` only falls back to
`.bak` when `last.json` is **invalid**, not when it is merely smaller.

**Fix:** in `save()`, if a valid `last.json` exists and the new capture has
significantly fewer clients (e.g. < 50%), do not overwrite it.

#### C2 — `Session.qml` logout has no `||` fallback [gap]

`Session.qml:40-42`: `save-auto-if-stale && sumika-logout` — a failed save
silently blocks logout. `poweroff`/`reboot` fall back to `loginctl`.
**Fix:** add `|| sumika-logout` so logout proceeds even if save fails.

#### C3 — kitty pane replay closes the pane after the command exits [gap]

`kitty_pane_command` generates `<shell> -c "<cmd>"`; the pane closes when the
command exits (non-interactive `-c`). The original pane was an interactive
shell running the command. **Fix:** keep an interactive shell after the
command: `<shell> -c "<cmd>; exec <shell>"` so the pane stays open.

### D. QML / UX

#### D1 — Right-click power menu has no checkbox, always saves [gap]

`PowerContextMenu.qml:78,88,98` hardcode `saveCurrentSession = true`. Only
the left-click popup / launcher confirm paths show the checkbox. Decide
whether the right-click menu should also respect the checkbox or default to
the last checkbox state.

#### D2 — Restore overlay cannot be cancelled [gap]

`SessionRestoreOverlay.qml` is fullscreen for the restore duration + 850ms
with no cancel path. A wrongly-triggered restore (A1/A2/A3) launches apps
with no way to stop it. Consider a cancel affordance.

#### D3 — `restoreAction` default is a footgun [minor]

`SessionRestoreOverlay.qml:17` defaults to `"restore"` (not
`"restore-auto"`), which would not consume the marker. It is always
overwritten by the host (`SessionAutoRestore.qml:151`), but the default is a
value that silently breaks the marker lifecycle. Make it `required`.

### E. Naming-space residue (out of scope for this pass)

`LockContext.qml:27` writes `/tmp/omd-lock` (retired `omd` namespace).
`share/bin/omarchy-*` scripts keep the old name. Tracked separately under the
Sumika namespace migration; not addressed here.

## Fix order

1. A1 + A2 (save-requested flag; empty save unlinks marker) — contract core
2. A3 (consume marker on skip; savedAt age gate)
3. A4 (fail-safe on failing tool)
4. B1–B5 (cleanup)
5. C1–C3 (python engine)
6. Verify