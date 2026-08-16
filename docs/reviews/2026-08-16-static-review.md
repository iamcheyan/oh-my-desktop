# Sumika Shell Static Review — 2026-08-16

## Scope and method

Repositories reviewed:

- Main: `sumika-shell`, deep range `fd5fec5..2f6c550` plus a coarse scan of the remaining tree.
- Extensions: `sumika-shell-extensions`, all eight extension directories: `active-window`, `file-backup`, `input-method`, `keyboard-remap`, `screenshot`, `theme-settings`, `voice`, and `windows-vm`.

Ten read-only reviewers covered session/systemd/bin scripts, clipboard, services, common/bar/settings QML, feature modules, Hyprland/labwc/share-bin, the main-repo coarse scan, and three extension groups. Findings were checked against current source before changing code. The 2026-08-14 review was used as the baseline; its already-known deferred issues are not repeated here unless a current-tree regression was found.

This machine has no Hyprland or Quickshell runtime. Review and verification are static only. QML and Lua were inspected by source; shell/Python/JSON syntax was checked where tooling exists. No bar restart, `systemctl --user restart/stop sumika-bar`, `pkill quickshell`, or compositor runtime command was used.

## Fixed — main repository

| Severity | Evidence | Issue and repair |
|---|---|---|
| Important | `lib/paths.sh:25-32` | `${BASH_SOURCE[0]}` was expanded unconditionally in a POSIX `/bin/sh` file, producing dash `Bad substitution`. Bash keeps the sourced-file lookup; dash uses the caller `$0` path used by repository scripts. |
| Important | `bin/sumika-session:810-830`, `:1055-1087`, `:1164-1208` | Rolling snapshots could be younger than 15 seconds when the compositor died; `save_auto_if_stale` then skipped `CompositorGone` recovery and disarmed restore. Rolling and shutdown writers also shared `last.json.tmp`, allowing one `os.replace` to remove the other writer's temp file. Recent rolling snapshots now probe compositor reachability before disarming, and atomic writes use unique temporary files. |
| Important | `share/bin/sumika-launch-tui:20-24` | Explicit `--app-id` bypassed the alphanumeric/dot app-id contract, so underscores were silently removed by Wayland and Hyprland TUI rules missed. Invalid overrides are rejected. |
| Important | `share/bin/sumika-trackpad-revive:121-185` | Preventive silent-wedge recovery was unreachable: keyboard activity in the probe window made `check_health` return `dead` before the preventive branch, while the preventive branch required that same activity. A recent keyboard-activity stamp now decouples session activity from the three-second probe. |
| Important | `hypr/hyprland.lua:58-60`, `hypr/screenshot.lua:1-4` | Screenshot Settings edits `hypr/screenshot.lua` and promises reload, but `require("screenshot")` cached the module across Lua reloads. The binding file is now loaded with `dofile`, matching the reload contract. |

## Fixed — extensions repository

| Severity | Evidence | Issue and repair |
|---|---|---|
| Critical | `keyboard-remap/share/polkit-1/rules.d/50-sumika-keyboard.rules:23-59` | The rule granted `YES` to any active user whose command line contained one of a few substrings. An active user could place an arbitrary command beside the matching text. The rule now pins bash, validates the complete payload shape and generated-path characters, and requires `wheel` or `sumika` membership. `keyboard-remap/bin/omarchy-keyboard-apply:67-70` was aligned to that exact payload and its non-systemd commands were removed from the passwordless payload. |
| Critical | `file-backup/polkit/50-sumika-backup.rules:20-38` | The rule authorized any active user when `command_line` contained `mount.cifs`, including bash wrappers with arbitrary commands. It now checks the exact `mount.cifs`/`umount` executable path, command prefix, active session, and `wheel`/`sumika` membership. |
| Critical | `voice/bin/omarchy-voice-transcribe:26-37`, `:159-178` | The daemon bound `/tmp/sumika-voice.sock` with mode `0666`, allowing other local users to submit readable WAV paths and receive transcriptions. Socket and PID state now use `XDG_RUNTIME_DIR` (or `/run/user/<uid>`), stale legacy sockets are removed, and the socket is created with umask `0177` and mode `0600`. |
| Important | `input-method/config/schemas.json:3-33` | The extension tree shipped an empty schema list while the UI rendered four choices; selection and cycling were no-ops. The four shipped schemas (`sbzr`, `sbzr_mix`, `easy_en`, `jaroomaji`) are restored. |
| Important | `active-window/ActiveWindowMenu.qml:41-44` | Hyprland window actions read nonexistent `Toplevel.address`, so toggle floating/fullscreen/pop-out/scratchpad returned without dispatching. The code now imports `Quickshell.Hyprland` and reads `HyprlandToplevel.address`, adding the required `0x` selector. |
| Important | `windows-vm/scripts/windows-rdp:27-74` | RDP port parsing used gawk-only three-argument `match()` and silently fell back to port 3389 under Debian's mawk. The parser uses portable `sed`; compose credentials are now passed as `/u:` and `/p:` arguments to FreeRDP. |
| Important | `windows-vm/bin/sumika-settings-windows-vm:58-87` | `install-defaults` read YAML-escaped quotes/backslashes and escaped them again, progressively corrupting credentials. The read path now reverses the two escapes before rewriting. |
| Important | `theme-settings/bin/sumika-settings-theme:462-487` | Theme apply deleted the live theme before copying and generating derivatives. A failure could leave `theme/current` missing or partial. The new theme is built and generated in a temporary directory, then swapped into place with rollback on move failure. |
| Important | `screenshot/bin/sumika-screenshot:23-25`, `screenshot/apps/sumika-screenshot/regionSelector/{RegionSelector,RegionSelection}.qml` | The active flag and edit temporary image still used fixed `/tmp` names despite the runtime-path contract. They now use `XDG_RUNTIME_DIR` with the existing `/tmp` fallback only when the environment is unavailable. |
| Important | `voice/bin/omarchy-voice-record:4-5`, `voice/bin/sumika-settings-voice:35-36`, `:559`, `:595`, `:648`, `voice/VoiceInput.qml:52-56`, `:107`, `:159-163`, `:191`, `voice/bar/VoiceModelStatusPopup.qml:11-12`, `:101` | Recording WAV/PID/cancel state and daemon probes had to follow the moved socket. All shell and QML clients now use the same per-user runtime directory. |

## Reviewed but not changed

These findings are real or plausible but are Minor, metadata-only, already-baselined, or cannot be confirmed without the unavailable desktop runtime. They remain documented rather than expanded into feature work.

### Main repository

- `quickshell/services/HostInfo.qml:39-41`: notch detection uses any attached Apple-host screen with ratio `< 1.595`; a narrow external display can select the notched layout globally. Minor multi-monitor edge case.
- `quickshell/services/KeyringStorage.qml:32`: plain JavaScript string `.arg()` is invalid and can leave the keyring label empty. Minor; unrelated to the reviewed range's critical paths.
- `quickshell/modules/settings/module.json:8-10`: `${SUMIKA_SHELL_ROOT}` in a direct argv entry is not shell-expanded. The entry is currently latent (`autostart: false`) and the live builtin action supplies an expanded path. Minor/path-contract cleanup.
- `quickshell/modules/display/settings/DisplayPage.qml:171-186`: the performance dropdown's `currentValue` binding is lost after the first self-assignment, so it can become stale after a PowerPopup change. Minor UI state drift.
- `quickshell/modules/clipboard/bin/sumika-kitty-smart-paste:105-107`: a failed MIME-specific decode falls back to PNG without changing the original extension. `quickshell/modules/clipboard/apps/sumika-clipboard/services/Cliphist.qml:89-105` can prune in-flight thumbnail temp files. `quickshell/modules/clipboard/bin/sumika-clipboard-image-path:39-43` does not break after `--`, and `quickshell/modules/clipboard/bin/sumika-clipboard-image-path:97` records dedupe state before its `:109-111` copy succeeds. These are Minor/latent clipboard defects.

- Trackpad error files and screenshot snapshot intermediates still use `/tmp` in paths that are random or internal temporary artifacts; those are covered by the 2026-08-14 baseline and were not re-scoped.

### Extensions repository

- `active-window/ActiveWindowMenu.qml:68-73`: Hyprland Force Quit still uses focused `killactive` despite a comment promising an address-scoped fallback. Minor focus-race/documentation mismatch; the four address-scoped operations are repaired.
- `voice/VoiceInput.qml:159-163`: a stale runtime cancel flag can cancel the next recording if the bar exits before its polling process removes the flag. Minor; the fixed runtime path removes the cross-user `/tmp` exposure.
- `windows-vm/bin/sumika-settings-windows-vm:386-398`: the generated desktop entry copies an icon from an extension path that does not exist, producing a generic icon. `windows-vm/module.json:13-20` also carries a stale startup WM class; the actual launcher-derived ID is separately registered. Metadata/cosmetic only.
- The 2026-08-14 deferred issues remain deferred where the current tree still matches the documented behavior: voice download integrity/heartbeat and hardcoded settings paths, keyboard-remap duplicated preset tables and known TUI fallback, screenshot OCR/install/upload concerns, active-window app-name force-quit limitations, file-backup auditability, and windows-vm polling/icon metadata.
- No runtime claim is made for QML rendering, Hyprland dispatch, polkit engine behavior, Quickshell singleton loading, or Lua reload execution. The screenshot `dofile` fix is source-verifiable because the old `require` cache contradicted the file's explicit reload contract; actual compositor behavior remains untested.

## Commits pushed

### Main repository (`github.com/iamcheyan/oh-my-desktop`)

- `1926621` — `lib/paths.sh: fix dash 'Bad substitution' when sourced by POSIX sh`
- `1d1177e` — `session: harden rolling saves and TUI app IDs`
- `b15be9d` — `trackpad-revive: make preventive recovery reachable`
- `afaf377` — `hypr: reload screenshot bindings after edits`

### Extensions repository (`github.com/iamcheyan/sumika-shell-extensions`)

- `8cd77f4` — `extensions: fix polkit scope and Windows VM launch paths`
- `47daa32` — `voice: move daemon and recording state to private runtime dir`
- `58dc875` — `screenshot: keep session flags and edit captures per-user`

All listed commits were pushed to their respective `main` branches during the review.

## Verification

Commands run:

```text
python3 tests/test_python_tuis.py
s....
Ran 4 tests in 0.021s
OK (skipped=1)

sh -n lib/paths.sh bin/sumika-trackpad-revive
bash -n share/bin/sumika-launch-tui share/bin/sumika-trackpad-revive
python3 -m py_compile bin/sumika-session bin/sumika_tui_framework.py
main repair-point syntax: PASS

bash -n <modified extension shell scripts>
python3 -m py_compile voice/bin/omarchy-voice-transcribe
jq -e '.schemas | length == 4' input-method/config/schemas.json
extension repair-point syntax/schema: PASS

windows-vm/scripts/windows-rdp with stub xfreerdp3:
/v:127.0.0.1:3397
/u:alice
/p:secret
windows-rdp port/credential forwarding: PASS
```

`bin/sumika-doctor` was run. It completed with exit 1 because this workstation intentionally has no `qs`/Quickshell, Hyprland, `hyprctl`, or `hyprpicker`; it reported the expected runtime absence. Available backend checks and static paths passed where installed. No `hyprctl reload`, Quickshell launch, or bar restart was attempted.
