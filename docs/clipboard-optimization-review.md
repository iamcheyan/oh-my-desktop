# Clipboard Refactor — Optimization Review

Reviewed the post-refactor clipboard code under `apps/omd-clipboard/` plus the
mirrored `quickshell/services/Cliphist.qml`. Goal: remove dead code and tighten
structure/perf. This is a **review + proposal** — no edits applied yet.

## Scope of files reviewed

- `apps/omd-clipboard/shell.qml`
- `apps/omd-clipboard/GlobalStates.qml`
- `apps/omd-clipboard/modules/clipboard/ClipboardDialog.qml`
- `apps/omd-clipboard/modules/clipboard/widgets/ClipboardItem.qml`
- `apps/omd-clipboard/modules/clipboard/widgets/CliphistImage.qml`
- `apps/omd-clipboard/modules/clipboard/widgets/{Appearance,Directories,FileUtils,Fuzzy,StyledText,TuiStyle,CosmicIcon,StringUtils}.qml`
- `apps/omd-clipboard/modules/clipboard/widgets/fuzzysort.js`
- `apps/omd-clipboard/services/Cliphist.qml`
- `quickshell/services/Cliphist.qml` (parallel copy)
- Legacy/dead: `quickshell/modules/bar/ClipboardDialog.qml`,
  `quickshell/modules/bar/ClipboardItem.qml`,
  `quickshell/modules/common/widgets/CliphistImage.qml`
- Bin/scripts: `bin/omd-clipboard`, `bin/omd-clipboard-store`,
  `scripts/omd-quickshell-stop.sh`

---

## Part 1 — Dead / Unneeded Code

### A1. Three legacy clipboard files are fully dead (799 lines)

The pre-split clipboard UI still lives under `quickshell/` but is **not imported
anywhere**:

| File | Lines | Last referenced by |
|---|---|---|
| `quickshell/modules/bar/ClipboardDialog.qml` | 508 | nothing (only `apps/omd-clipboard/shell.qml` uses the new `ClipboardDialog`, and it imports the app-local copy) |
| `quickshell/modules/bar/ClipboardItem.qml` | 134 | nothing |
| `quickshell/modules/common/widgets/CliphistImage.qml` | 157 | only the dead `bar/ClipboardDialog.qml` above |

`grep` confirms no remaining import or instantiation. The bar module has been
migrated to the standalone `omd-clipboard` process (launched via
`ClipboardButton.qml → bin/omd-clipboard toggle`); the bar no longer hosts an
inline clipboard dialog.

**Action:** delete all three files. After deletion, also drop the
`wl-paste ... omd-bar ipc call cliphistService update` call in
`bin/omd-clipboard-store` (see A2) — the bar no longer needs Cliphist refresh.

### A2. `omd-clipboard-store` notifies the bar's Cliphist, which is unused there

`bin/omd-clipboard-store` runs two `wl-paste --watch` handlers and, after each
store, pokes **both** `omd-clipboard` and `omd-bar` via IPC:

```sh
qs -p .../omd-clipboard ipc call cliphistService update
qs -p .../omd-bar       ipc call cliphistService update
```

`omd-bar` only referenced `Cliphist` through the now-dead
`bar/ClipboardDialog.qml`. With A1 done, the bar process loads `Cliphist.qml`
as a singleton but never consumes it — every clipboard copy pays an extra `qs
ipc` round-trip to wake a service that does nothing.

**Action:** remove the `omd-bar` IPC line from both watchers in
`bin/omd-clipboard-store`.

### A3. `Cliphist.copy()` and `Cliphist.superpaste()` are never called

```sh
$ grep -rn "Cliphist\.copy\b\|superpaste" --include='*.qml'
# only the definitions in Cliphist.qml themselves
```

No UI, no IPC handler, no script invokes them. `superpaste` also hardcodes the
"cliphist" decode path and ignores the Stash branch the rest of the file
supports, so even if revived it would be inconsistent.

**Action:** delete `copy()` and `superpaste()` from both `Cliphist.qml` copies.

### A4. `scoreThreshold` property is unused

`property real scoreThreshold: 0.2` is declared but `fuzzyQuery` never reads it
(it passes `{all: true, key: "name"}` only). The only other `scoreThreshold` in
the repo is in `AppSearch.qml`, unrelated.

**Action:** remove the property.

### A5. Stash binary branch is dead config

`Cliphist.qml` keeps a commented-out `cliphistBinary` for `stash` plus
`if (root.cliphistBinary.includes("cliphist")) ... else { // Stash ... }`
branches in `copy`, `paste`, `pasteImagePath`, and `superpaste`. The binary is
hardcoded to `"cliphist"`; nothing flips it to stash. Every paste path carries
a runtime `.includes("cliphist")` check for a configuration that cannot be
selected.

**Action:** drop the Stash branches and the commented `cliphistBinary` line.
Keep a single cliphist code path. (If stash support is ever needed, restore it
via a single `cliphistBinary` switch, not duplicated branches.)

### A6. `FileUtils.qml` singleton has a single helper used only in a dead comment

`FileUtils.trimFileProtocol` is referenced once — inside the commented-out
stash `cliphistBinary` line (A5). With A5 applied, `FileUtils.qml` and its
`qmldir` entry are fully unused.

**Action:** delete `FileUtils.qml`, drop its `qmldir` entry.

### A7. `CosmicIcon.qml` is unused

No reference outside its own file and the `qmldir` entry. It also depends on
`Directories.assetsPath`, which itself is hardcoded to
`~/Development/oh-my-desktop/quickshell/assets` (wrong path — the repo is
`~/development/OMD`; see B4).

**Action:** delete `CosmicIcon.qml`, drop its `qmldir` entry. This also makes
`Directories.assetsPath` removable (B4).

### A8. `StringUtils.qml` carries 14 functions; only 2 are used by clipboard

Used: `shellSingleQuoteEscape` (9 call sites), `cleanCliphistEntry` (1 site).
Unused by any clipboard code: `format`, `getDomain`, `getBaseUrl`,
`splitMarkdownBlocks`, `escapeBackslashes`, `wordWrap`, `cleanMusicTitle`,
`friendlyTimeForSeconds`, `escapeHtml`, `stringListContainsSubstring`,
`cleanPrefix`, `cleanOnePrefix`, `toTitleCase`.

`splitMarkdownBlocks` alone is ~100 lines of markdown/think-block parsing that
has nothing to do with a clipboard menu.

**Action:** trim `StringUtils.qml` to the two used functions. (The bar's
`StringUtils.cleanMusicTitle` lives in the separate
`quickshell/modules/common/functions/StringUtils.qml` — unaffected.)

### A9. `StyledText.qml` carries an unused text-change animation

`animateChange`, `animationDistanceX/Y`, and the whole `Behavior on text`
`SequentialAnimation` block are never enabled — no caller sets
`animateChange: true`. The clipboard only uses `StyledText` as a styled `Text`.

**Action:** strip the animation machinery; keep `StyledText` as a thin `Text`
with the default font/color bindings. Saves per-instance overhead on every
styled label (the dialog creates 8 of them).

### A10. `shell.qml` — dead `dismissGuard` Timer and HyprlandData symlink

- `dismissGuard` Timer (shell.qml:149) has an empty `onTriggered` body and is
  never started or read. Pure leftover from the pre-decouple grab logic.
- `services/HyprlandData.qml` is a symlink into `quickshell/services/`, but no
  file under `apps/omd-clipboard/` imports or references `HyprlandData`.

**Action:** remove `dismissGuard`. Remove the `HyprlandData.qml` symlink.

### A11. `Directories.shellConfig` is unused

Only `cache` and `cliphistDecode` are read (plus `assetsPath`, see A7).
`config` and `shellConfig` are unused.

**Action:** drop `config`, `shellConfig`, and (after A7) `assetsPath` from
`Directories.qml`.

### A12. `Appearance.qml` over-nested font object

`Appearance.font.pixelSize.{smallest,smaller,small,normal,large}` — only
`small` is read (and only by `StyledText`, which we're slimming). The whole
`pixelSize` sub-object is dead weight.

**Action:** reduce to `Appearance.font.family.main` only; drop `pixelSize`
sub-object. (Alternatively inline the family string where used and delete
`Appearance.qml` entirely — see proposal B1.)

### A13. `maxEntries` mismatch between the two Cliphist copies

`apps/omd-clipboard/services/Cliphist.qml` caps at **100**, while
`quickshell/services/Cliphist.qml` caps at **40**. The dialog's
`maxVisibleRows` already clamps display to ~screen-70%, so 100 just means more
filtering/JSON work on each refresh for no visible benefit. The
`docs/clipboard-menu.md` design says 40.

**Action:** align both to 40.

---

## Part 2 — Structure / Performance

### B1. Collapse the widget-singleton pile into one small file

The app carries 7 singletons (`Appearance`, `TuiStyle`, `Directories`,
`FileUtils`, `Fuzzy`, `StringUtils`, + `CosmicIcon` widget) to support a
~370-line dialog. After A6/A7/A8/A11/A12 the survivors are:

- `TuiStyle` — 9 color/radius tokens (keep, or inline).
- `Directories` — 2 paths (`cache`, `cliphistDecode`).
- `Fuzzy` — thin wrapper over `fuzzysort.js`.
- `StringUtils` — 2 functions.
- `Appearance` — 1 font family string.

**Proposal:** merge `Directories`, `StringUtils`, `Appearance`, and `TuiStyle`
into a single `ClipboardStyle.qml` singleton (or even inline the ~20 constants
directly into the two files that use them). Fewer singletons = fewer QML
component instantiations at cold start, which matters because this process is
on-demand and quits on close. `Fuzzy` + `fuzzysort.js` stay separate (682-line
vendored lib).

### B2. `preparedEntries` rebuilds on every `entries` change — fine — but it's a binding, not cached

```qml
readonly property var preparedEntries: entries.map(a => ({...}))
```

This is OK, but `fuzzyQuery` is called from a binding in `ClipboardDialog`:

```qml
readonly property var filteredEntries: searchText.length > 0 ? Cliphist.fuzzyQuery(searchText) : Cliphist.entries
```

Every keystroke re-runs `Fuzzy.go` over up to 40 prepared entries and allocates
a new result array. That's acceptable for 40, but the result is then fed into a
`ScriptModel { values: filteredEntries }`, which rebuilds the model on every
keystroke. Two improvements:

1. **Debounce search** with a ~30–50ms `Timer` so fast typing doesn't re-run
   fuzzy + model rebuild per key.
2. **Reuse the no-search path**: when `searchText` becomes empty, return
   `Cliphist.entries` directly (already done) — but also avoid the `.map(r =>
   r.obj.entry)` allocation in `fuzzyQuery` by having fuzzysort operate on the
   raw entry strings as targets instead of wrapping in `{name, entry}` objects.
   `fuzzysort.go` supports `key: "name"` on objects, but it also supports
   passing prepared strings directly; dropping the wrapper halves allocations.

### B3. `entryIsImage` recompiles a regex on every call

```js
function entryIsImage(entry) {
    return !!(/^\d+\t\[\[.*binary data.*\d+x\d+.*\]\]$/.test(entry))
}
```

Called from `ClipboardItem.isImage` (once per visible row, ~12 rows), from
`filterEntries` (once per raw entry, up to 100), from `entryHasVisibleContent`,
from `previewIsImage`, and from `pasteSelected`. Each call recompiles the
literal. Hoist the regex to a module-level `const` so it's compiled once.

Same for `entryPayload`'s `/^\s*\S+\s+/` and the invisible-char regex in
`entryHasVisibleContent` — both are recompiled per entry per refresh.

### B4. `Directories.assetsPath` hardcodes a wrong path

`~/Development/oh-my-desktop/quickshell/assets` — the actual repo is
`~/development/OMD`. Dead anyway (A7), but worth noting as a latent bug if
anyone re-enables `CosmicIcon`.

### B5. `CliphistImage.qml` duplicates the decode command and re-parses entry metadata 3×

- `entryNumber`, `imageWidth`, `imageHeight` each run
  `entry.match(/(\d+)x(\d+)/)` or `entry.match(/^(\d+)\t/)` independently.
- `decodeImage()` builds `checkAndDecode.command` imperatively **and** the
  `Process` has a static `command:` binding with the same template — two
  sources of truth. The static one uses `imageDecodeFilePath` (always
  evaluated), the imperative one uses a local `filePath` — they're equal but
  it's confusing and the static binding does shell-escape `root.entry` on every
  entry change even when `active` is false.

**Proposal:**
- Parse `entry` once into a small `{num, w, h}` object via a single
  `entry.match(/^(\d+)\t\[\[.*?(\d+)x(\d+).*\]\]$/)` (also validates image
  shape).
- Drop the static `command:` binding on `checkAndDecode`; set it only inside
  `decodeImage()` when actually decoding (already half-done). This avoids
  escaping `root.entry` on every property change.

### B6. `ClipboardItem.qml` re-parses image dimensions independently

`ClipboardItem` computes `imgW`/`imgH` via its own `entry.match(/(\d+)x(\d+)/)`
— the same parse `CliphistImage` does. If `ClipboardItem` always shows a
`CliphistImage` for image rows, it can read `imageWidth`/`imageHeight` off the
child instead of re-parsing. Minor, but removes a double regex per row.

### B7. `textDecoder` Process has no `command` binding — relies on imperative set

`ClipboardDialog.qml:105` declares `Process { id: textDecoder; property string
decodedText: "" ... }` with no `command`. `loadPreview()` sets
`textDecoder.command` then `running = true`. This works, but on the very first
preview the Process component is instantiated with an empty command; depending
on Quickshell version it may log. Safer: give it a static no-op `command: ["true"]`
or gate `running` behind a non-empty command.

### B8. `Quickshell.onClipboardTextChanged` fires for our own paste path writes

`pasteImagePath` writes `/tmp/omd-clip-<ts>.png ` to the clipboard via
`wl-copy`, which triggers `Quickshell.onClipboardTextChanged` →
`delayedUpdateTimer` → `refresh()`. Then `filterEntries` filters out
`/tmp/omd-clip-` payloads, so the new entry is discarded — but we still paid a
full `cliphist list` + filter pass for nothing, racing with the paste itself.

The `omd-clipboard-store` text watcher already rejects `/tmp/omd-clip-` before
`cliphist store`, so cliphist never stores it. The `onClipboardTextChanged`-
driven refresh in the *service* is therefore redundant for this case and
mostly redundant in general because `omd-clipboard-store` already sends
`cliphistService update` IPC after every real store.

**Proposal:** drop the `Quickshell.onClipboardTextChanged` Connections in
`Cliphist.qml` entirely and rely on the `cliphistService update` IPC from
`omd-clipboard-store` as the single source of refresh. This removes a
duplicate refresh path and the paste-time race. (Keep `delayedUpdateTimer` only
if we want a local fallback; if kept, bump interval from 20ms to ~150ms to
coalesce bursts.)

### B9. `saveToCache` spawns a `bash -c` on every successful refresh

`saveToCache` runs `mkdir -p ... && printf %s '...' > file` via
`Quickshell.execDetached` after every `refresh()`. Refresh fires on every
clipboard copy (via IPC) and on every delete/wipe. For an on-demand process
that quits when the menu closes, the cache file's value is marginal (the next
open re-reads cliphist list anyway, and `omd-clipboard-store` is the persistent
component). Meanwhile every cache write spawns a shell and quotes the entire
entries JSON through `shellSingleQuoteEscape` — which is risky for large
histories (shell arg length, quoting bugs).

**Proposal:** remove `saveToCache` + `cacheFileView` + `cacheDir`/`cacheFile`
properties (the ~25 lines added in `apps/omd-clipboard/services/Cliphist.qml`
that aren't in the main `quickshell/services/Cliphist.qml`). The "first frame
doesn't wait for cliphist read" benefit in `docs/clipboard-menu.md` is small
(cliphist list of 40 entries is <10ms) and doesn't justify a persistent cache
layer with shell-quoted JSON writes. If we want instant first paint, keep an
in-memory last-result on the *store* side, not a JSON file.

### B10. `shell.qml` cursor/monitor resolution spawns two sequential `hyprctl` processes

On every open: `hyprctl cursorpos -j` → parse → `hyprctl monitors -j` → parse
→ loop screens. Two process spawns + JSON parses serially add ~30–80ms to open
latency. `hyprctl monitors -j` output rarely changes during a single open; we
could cache the monitor→screen map on `Component.onCompleted` (one spawn) and
only re-fetch cursor pos on open (one spawn). Or use `Quickshell.screens` +
the focused monitor from `HyprlandData` if we keep the symlink (A10 removes
it, so simplest: cache monitors).

**Proposal:** fetch monitors once at startup; on open, fetch only cursor pos
and match against the cached monitor list. Halves the spawn count per open.

### B11. Two copies of `Cliphist.qml` drift

`apps/omd-clipboard/services/Cliphist.qml` and `quickshell/services/Cliphist.qml`
are ~90% identical but have already drifted: the app copy has the cache layer
(B9) and `maxEntries: 100` (A13); the main copy uses
`Config.options.hacks.arbitraryRaceConditionDelay` for the timer. The bar no
longer needs `Cliphist` (A1), so `quickshell/services/Cliphist.qml` is only
loaded as a singleton by the bar process for no reason.

**Proposal:** after A1, delete `quickshell/services/Cliphist.qml` and the bar's
`import qs.services`-triggered load of it (the bar imports `qs.services` for
other services, so we can't drop the import; but we can remove the file —
Quickshell only instantiates singletons that are imported, and if nothing in
the bar references `Cliphist` it won't be instantiated... actually QML
singletons are instantiated on first import resolution, so removing the file
is the only clean way). Keep the app-local copy as the single source of truth.

### B12. `filterEntries` does `entryPayload` + `entryHasVisibleContent` per entry, each re-regexing

`entryHasVisibleContent` calls `entryIsImage` (regex) + `entryPayload`
(regex) + `.replace(invisible, "")` (regex). For 40 entries this is ~120
regex compilations. Hoist all three regexes to module-level constants (B3) and
the cost drops to 40 executions of precompiled patterns.

---

## Priority / Suggested Order

**High value, low risk (pure deletion):**
A1, A2, A3, A4, A5, A6, A7, A10, A11 → ~1000+ lines removed, no behavior change.

**Medium (deletion + trim):**
A8, A9, A12, A13, B9 → another ~150 lines + remove a shell-spawning cache path.

**Perf (structural):**
B3, B5, B6, B8, B10, B12 → regex hoist + drop redundant refresh + halve open
latency. Low risk, measurable on cold open.

**Structural cleanup (bigger):**
B1, B11 → singleton consolidation + single Cliphist source of truth. **Done.**
`Appearance`/`Directories`/`StringUtils`/`TuiStyle` merged into one
`ClipboardStyle.qml` singleton (25 lines). App singletons: 7 → 2
(`ClipboardStyle` + `Fuzzy`).

B2 (debounce + fuzzysort target reuse) → debounce **Done**: 40ms
`searchDebounce` Timer; empty-state label still reads live `searchText` for
instant feedback, while `filteredEntries`/model rebuild reads debounced
`debouncedSearch`. (fuzzysort target-reuse skipped — 40 entries is fast enough.)

B4 (dead path), B7 (Process command guard) → **Done**.

---

## Open Questions

1. **Keep the entries cache at all?** B9 proposes removing it. If you want
   instant first paint even when cliphist is slow, we can keep an in-memory
   copy in `omd-clipboard-store` instead of a JSON file. Preference?
2. **Keep `Quickshell.onClipboardTextChanged` as a fallback refresh?** B8
   proposes dropping it and relying on the store's IPC. The store is the
   component that actually calls `cliphist store`, so it's the authoritative
   "something changed" signal. OK to drop the clipboard-text listener?
3. **Stash support** — A5 removes it. It's been unused since the cliphist
   switch. Confirm we won't bring `stash` back?
4. **`Appearance.qml` vs inline** — B1/A12: do you prefer keeping a tiny
   `Appearance` singleton for font family, or inlining the family string
   (`"MesloLGS Nerd Font"`) into the 3 use sites?
5. **Singleton consolidation scope** — B1: merge `TuiStyle` + `Directories` +
   `StringUtils` + `Appearance` into one `ClipboardStyle.qml`, or keep
   `TuiStyle` separate (it's the closest to the repo-wide style system)?

---

## Estimated Impact

- Lines removed: ~1150 (mostly A1's 799 + StringUtils trim + cache layer).
- Singletons in the app: 7 → 2–3.
- Cold-open process spawns: 2 → 1 (B10).
- Per-copy refresh work: removes a `bash -c` cache write + a redundant
  `cliphist list` on self-paste (B8/B9).
- Regex compilations during refresh: ~120 → 0 (all hoisted).

No user-visible behavior changes expected for A1–A13 and B3/B5/B6/B8/B10/B12.
B1/B9/B11 are structural and should be verified by opening the menu, searching,
pasting text + image, deleting an entry, and wiping.