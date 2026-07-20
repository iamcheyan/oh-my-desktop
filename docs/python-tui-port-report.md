# Python settings TUI port audit

Last audited: 2026-07-19

## Goal

The active settings TUI entry point now routes these four pages to Python
`curses` implementations:

```text
bin/omd-settings-tui
├── keyboard -> bin/omd-settings-keyboard-tui
├── theme    -> bin/omd-settings-theme-tui
├── voice    -> bin/omd-settings-voice-tui
└── windows  -> bin/omd-settings-vm-tui
```

The Python pages follow the same backend commands and progressive disclosure
pattern inherited from the Go prototypes. No tui-go sources remain in the repo.

## Audit correction

The first version of this report said that every port was complete and claimed
between 8,000 and 14,000 new lines per page. Those figures were incorrect. At
the time of this audit the complete Python implementation is 3,634 lines:

| File | Lines |
|---|---:|
| `bin/omd_tui_shared.py` | 559 |
| `bin/omd-settings-keyboard-tui` | 946 |
| `bin/omd-settings-theme-tui` | 763 |
| `bin/omd-settings-vm-tui` | 610 |
| `bin/omd-settings-voice-tui` | 756 |

The earlier report described intended features as if they had been verified.
This document records behavior that was compared with the Go source and then
tested through the real launcher.

## Shared runtime

`bin/omd_tui_shared.py` provides the Python equivalent of the Go UI and backend
helpers:

- centralized colors, text styles, borders, controls, Hero and help rows;
- OMD command lookup and stdout/stderr capture;
- worker-thread command execution with callbacks serialized onto the curses
  main thread;
- SGR mouse setup, mouse decoding and text hit testing;
- CJK-aware terminal column measurement, truncation, padding and wrapping;
- wrapped-log scrolling and scrollbars based on rendered rows;
- stable fallback for terminals too small to contain a page;
- graceful degradation when colors or 256-color pairs are unavailable.

The main-thread callback queue is required. Calling curses rendering state from
a command worker produced intermittent redraw failures and page crashes.

## Page parity

### Keyboard Remap

Implemented and checked against the Go page:

- connected and saved/offline keyboard profiles;
- exact device identity matching for the optional `-keyboard` suffix;
- profile enable state, presets and per-preset target overrides;
- visual key picker;
- profile copy between devices;
- Fn row mode status and cycling;
- setup, tester, apply, discard and refresh actions;
- pending/apply status, activity log and keyboard/mouse navigation.

The suffix fix is important: Python's former `rstrip("-keyboard")` removed any
combination of those characters, rather than the exact suffix, and could merge
unrelated device identities.

### Theme and wallpaper

Implemented and checked against the Go page:

- theme list, current theme and keyboard/mouse grid navigation;
- theme apply without closing the page;
- file, folder and solid-color wallpaper modes;
- next/stop folder rotation controls and interval adjustment;
- performance, balanced and visual wallpaper effects;
- current wallpaper preview and theme color swatches;
- responsive single-column layout below 108 terminal columns.

Theme image colors are mapped to the terminal's xterm-256 palette. The previous
allocator could request color and pair indices outside the curses capability
range.

### Voice Input

Implemented and checked against the Go page:

- initial diagnosis and status refresh;
- setup, model download/delete, bindings, key tester and TUI test actions;
- trial recording, cancel, transcribe and recent-history clear;
- faster refresh while recording/downloading;
- download/log view, model state and configured trigger display;
- keyboard/mouse navigation and rendered-row log scrolling.

The Python page previously crashed after diagnosis because the shared Hero
fallback referenced an undefined style. It also refreshed backend logs while a
trial recording was producing local logs, overwriting the live trial output.
Both behaviors are fixed. Quitting now cancels an active trial first.

### Windows VM

Implemented and checked against the Go page:

- KVM, Docker, Compose, FreeRDP and disk requirement diagnostics;
- install/fix, start, connect, web console, stop and remove actions;
- installed/running/ready state-specific content;
- connection details, container logs and three-second refresh;
- confirmation before destructive removal;
- keyboard/mouse navigation and rendered-row log scrolling.

`remove --yes` must be passed as two arguments. Both the Python port and the Go
reference were corrected; passing it as one string made confirmed removal a
no-op.

## Reliability fixes made during the audit

1. Background callbacks now run on the curses main thread.
2. Periodic refresh no longer sets the same busy lock used by user actions.
3. Refresh operations cannot overlap and race stale responses into the model.
4. Command stderr is retained and non-zero exits report `exit N`.
5. Unicode/CJK clipping and border alignment use terminal display width.
6. Long log entries wrap and scroll by visible terminal row.
7. Narrow terminals use single-column layouts or a resize message instead of
   drawing panels outside the screen.
8. Mouse mode is disabled in `finally` on normal exit and exceptions.
9. Voice supports the missing `t` test action and safely exits active trials.
10. VM removal and keyboard identity normalization use correct argument/string
    semantics.

## Verification

Static and regression tests:

```sh
python3 -m py_compile \
  bin/omd_tui_shared.py \
  bin/omd-settings-keyboard-tui \
  bin/omd-settings-theme-tui \
  bin/omd-settings-vm-tui \
  bin/omd-settings-voice-tui

python3 -m unittest discover -s tests -p 'test_python_tuis.py' -v

```

The Python regression tests cover display-width helpers, log wrapping, command
errors, main-thread callbacks, exact keyboard identity normalization, safe Hero
fallbacks and the VM removal argument contract.

Real PTY smoke tests were also run through the production router:

```sh
TERM=xterm-256color bin/omd-settings-tui keyboard
TERM=xterm-256color bin/omd-settings-tui theme
TERM=xterm-256color bin/omd-settings-tui voice
TERM=xterm-256color bin/omd-settings-tui windows
```

Each page loaded live backend state in an 80x24 PTY and exited cleanly. The
voice page was left running through completion of its startup diagnosis to test
the asynchronous state transition that previously crashed.

## Technical limits

These differences cannot be removed with Python's standard library alone:

1. **Image decoding:** `curses` and the Python standard library do not decode
   PNG/JPEG pixels. Theme previews use Pillow when it is already installed and
   otherwise fall back to text. Pillow remains optional; all controls work
   without it.
2. **Color precision:** Bubble Tea/lipgloss can emit 24-bit color. Portable
   curses uses the terminal's indexed palette, so the Python page approximates
   image and theme colors with xterm-256 colors.
3. **Mouse delivery:** the implementation emits standard SGR mouse mode, but
   the terminal emulator decides whether mouse events are delivered. Keyboard
   operation remains complete when mouse reporting is unavailable.
4. **Pixel-identical rendering:** lipgloss and curses have different layout and
   color models. Structure, controls, state, actions and responsive behavior are
   equivalent; escape sequences and exact color blending are not byte-for-byte
   identical.

No third-party package is required to launch or operate any of the four Python
pages.
