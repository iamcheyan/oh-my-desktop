# Go Settings TUI

OMD settings pages are moving toward small terminal UI programs launched as
floating Hyprland windows. The implementation target is Go + Bubble Tea so the
final deliverable can be a single binary without Python or Node runtime
dependencies.

## Layout

```text
tui-go/
├── cmd/omd-settings-tui/       CLI entry point and page routing
├── internal/backend/           Calls existing OMD shell backends
├── internal/pages/windows/     Windows VM settings page
├── internal/pages/theme/       Theme, wallpaper, and effects settings page
├── internal/pages/voice/       Voice input status, setup, and binding page
└── internal/ui/                Shared colors, buttons, panels, layout helpers
```

The launcher is:

```sh
bin/omd-settings-tui windows
```

`Init.sh` installs the Go toolchain and builds one binary for all routes:

```sh
./scripts/build-go-tools
```

The generated `tui-go/omd-settings-tui` file is machine-local and ignored by
Git. The launcher checks whether this binary is missing or older than any
`*.go`, `go.mod`, or `go.sum` source file. It rebuilds once when necessary and
otherwise starts immediately. Concurrent launch attempts share a build lock,
and the completed binary is installed atomically.

Compilation is deliberately not part of `omd-restart` or Quickshell reload.
Those commands are frequent runtime operations and must not depend on the Go
compiler or network access. Running `./Init.sh --runtime-only` also refreshes
the binary when Go is already installed, without installing packages.

For a forced development rebuild:

```sh
./scripts/build-go-tools --force
```

## Routes

```sh
bin/omd-settings-tui windows    # Windows VM settings and connection controls
bin/omd-settings-tui theme      # Theme picker and active theme info
bin/omd-settings-tui voice      # Voice input setup, model, and keybindings
```

Each route maps to a Go package under `internal/pages/<name>/` and a
thin backend script under `bin/omd-settings-<name>` (the Windows VM route
uses `bin/omd-settings-windows-vm`). The TUI owns layout, key handling,
and status rendering; all real work stays in the backend scripts so the same
operations are usable from Quickshell, the TUI, shell scripts, and future
automation.

### Backend contract

Status is read as `key=value` lines (parsed by `backend.ParseKV`).
Action subcommands return `key=value` lines plus optional `log=` lines that
the TUI surfaces in an action log. Two-step / privileged actions (keyd
apply, voice setup) are invoked through the backend which shells out to the
existing `share/bin/omarchy-*` implementations.

## Current Parity Scope

The Go TUI is intended to replace the Quickshell settings pages, so every page
must read and write the same runtime state as the old UI.

### Appearance / Theme

- Lists all user and system themes.
- Applies the selected theme through `bin/omd-settings-theme apply`.
- Shows the active theme colors.
- Controls wallpaper file/folder selection, folder rotation, next image, and
  rotation interval.
- Controls the display effects mode (`performance`, `balanced`, `visuals`) by
  writing the same Quickshell state file and applying the Hyprland eval string.

### Voice Input

- Uses the same model, venv, cache, socket, and binding file paths as
  `VoiceInput.qml`.
- Reports setup state from exact model-file and Python dependency checks.
- Runs setup plus model download from the existing voice scripts.
- Supports adding a binding through the existing key capture window.
- Supports removing bindings and opening the full binding editor TUI.
- Opens the existing voice test and diagnose TUI tools instead of duplicating
  their recording and diagnostic state machines inside Bubble Tea.

## Hyprland Floating Launch

Launch from a terminal with a stable app id:

```sh
foot --app-id org.omd.settings.tui -T "OMD Settings" -e ~/.config/omd/bin/omd-settings-tui windows
```

Use a Hyprland window rule for the app id:

```lua
o.window("org.omd.settings.tui", {
  float = true,
  center = true,
  size = { 1400, 900 },
})
```

## Design Rule

The TUI should stay thin. It owns layout, key handling, progress display, and
status rendering. Real system work stays in existing backend scripts such as:

```text
bin/omd-settings-windows-vm
```

That keeps the same operations usable from Quickshell, TUI, shell scripts, and
future automation.

## Polished Implementation Patterns

To ensure a highly responsive, premium-feeling terminal experience that aligns perfectly with the visual standards of the Quickshell UI, all new Go Settings TUI pages must follow these verified implementation patterns.

### 1. Terminal Size Initialization Guard (Startup Overflow Fix)

**Problem:** Bubble Tea renders its first frame *before* receiving the terminal's actual dimensions via `WindowSizeMsg`. By default, this frame renders at `120x36`. If the user's terminal window is smaller than 36 lines (e.g., 24 lines), this initial frame overflows the terminal buffer, causing the terminal window to scroll. Even when subsequent frames resize correctly, the TUI remains permanently shifted up, hiding the header in the scrollback.

**Solution:** Add a guard in the `View()` function to check if the width/height are uninitialized, returning a small string like `"Initializing..."` until size is established:

```go
func (m Model) View() string {
	if m.width <= 0 || m.height <= 0 {
		return "Initializing..."
	}
	// ... rest of rendering logic ...
}
```

### 2. ANSI Reset Background Preservation (`PreserveBackground`)

**Problem:** In terminal rendering, any ANSI reset code (`\x1b[0m`) printed inside a panel resets *all* terminal styling attributes, including the background color. Consequently, any trailing spaces or padded content after the reset will inherit the terminal's default background color (black), resulting in ugly, patchy black spaces inside styled gray panels.

**Solution:** Intercept all resets inside the panel content block and immediately re-inject the panel's background color escape sequence:

```go
func PreserveBackground(text string, bg lipgloss.Color) string {
	bgStyle := lipgloss.NewStyle().Background(bg)
	bgRendered := bgStyle.Render(" ")
	idx := strings.Index(bgRendered, " ")
	if idx < 0 {
		return text
	}
	bgSeq := bgRendered[:idx]
	// Replace all resets with reset + panel bg sequence
	textWithBg := strings.ReplaceAll(text, "\x1b[0m", "\x1b[0m"+bgSeq)
	return bgStyle.Render(textWithBg)
}
```

Apply this wrapper to the output of `FitBlock` before rendering the panel box:

```go
left := ui.PanelBox.Width(panelBoxW).Height(panelBoxH).Render(
	ui.PreserveBackground(ui.FitBlock(m.statusView(panelInnerW), panelInnerW, panelInnerH), ui.Panel),
)
```

### 3. Log Word Wrapping & Style Preservation

**Problem:** Truncating log lines hides critical diagnostic information. However, word wrapping can break ANSI styling if escape codes are split across lines without being closed or re-declared.

**Solution:** Wrap lines to the exact log viewport width (`width - 2` columns to reserve space for the scrollbar) using a custom wrapping function that tracks and propagates the active ANSI styling sequence to each new wrapped line:

```go
func WrapStyled(line string, width int) []string {
	if width <= 0 {
		return []string{line}
	}
	if lipgloss.Width(stripAnsi(line)) <= width {
		return []string{line}
	}

	var lines []string
	var current strings.Builder
	currentStyle := ""
	used := 0
	i := 0
	for i < len(line) {
		if line[i] == '\x1b' {
			seq, next := readAnsi(line, i)
			current.WriteString(seq)
			if seq == "\x1b[0m" {
				currentStyle = ""
			} else {
				currentStyle += seq
			}
			i = next
			continue
		}

		r, size := utf8.DecodeRuneInString(line[i:])
		if r == utf8.RuneError && size <= 1 {
			i++
			continue
		}
		rw := lipgloss.Width(string(r))

		if used+rw > width {
			current.WriteString("\x1b[0m")
			lines = append(lines, current.String())

			current.Reset()
			current.WriteString(currentStyle)
			used = 0
		}

		current.WriteRune(r)
		used += rw
		i += size
	}

	if current.Len() > 0 {
		lines = append(lines, current.String())
	}
	return lines
}
```

### 4. Viewport Logs Scrolling & Scrollbar Calculations

**Problem:** Logs need to be scrollable and feature a visual scrollbar track/thumb.
**Solution:** Store a `scrollOffset int` in the `Model`, clamp it based on `totalLines - logCount`, and calculate scrollbar thumb start and end positions relative to the log viewport height:

- Track track character: `│` (`ui.SubtleText`)
- Thumb character: `┃` (`ui.OKText` - Cyan Accent)

```go
// Calculate thumb ranges
thumbStart := (start * logCount) / totalLines
thumbEnd := (end * logCount) / totalLines
if thumbEnd-thumbStart < 1 {
	thumbEnd = thumbStart + 1
}

// Render log row with scrollbar character
sbChar := ui.SubtleText.Render("│")
if i >= thumbStart && i < thumbEnd {
	sbChar = ui.OKText.Render("┃")
}
displayedLogs[i] = ui.PadPlain(wrappedLogs[start+i], logWidth) + " " + sbChar
```

**Scrolling Keybindings:**
- `↑` / `k`: scroll up 1 line
- `↓` / `j`: scroll down 1 line (clamp min to 0)
- `PageUp`: scroll up 10 lines
- `PageDown`: scroll down 10 lines (clamp min to 0)
- `Home`: scroll to top (`scrollOffset = 999999`)
- `End`: scroll to bottom (`scrollOffset = 0` / automatic lock to bottom)

### 5. Mouse Support (Scrolling & Bounding-Box Clicks)

To build a fully mouse-reactive terminal app:

1. **Enable Mouse Tracking in CLI Entrypoint (`main.go`):**
   ```go
   tea.NewProgram(model, tea.WithAltScreen(), tea.WithMouseCellMotion())
   ```

2. **Handle Mouse Events in `Update`:**
   - **Scroll Wheel:** Intercept `tea.MouseWheelUp` / `tea.MouseWheelDown` events to update the `scrollOffset`.
   - **Clicks:** Intercept `tea.MouseActionPress` + `tea.MouseButtonLeft` events. Since there is no DOM, mathematically calculate the button bounding boxes `(X, Y)` relative to layout variables (`panelBoxW`, `panelInnerW`, `leftInnerX`, etc.).

```go
case tea.MouseMsg:
	if msg.Type == tea.MouseWheelUp {
		m.scrollOffset++
		return m, nil
	}
	// ... handling left clicks via calculated bounding box coordinates ...
```

### 6. Two-Step Danger Zone Confirmation

For destructive operations (e.g. "Remove VM"), prevent accidental activation by storing a `confirmRemove bool` state:
- Pressing the action key (e.g. `d`) sets `confirmRemove = true`.
- Update the bottom help bar to show confirmation options: `y confirm remove  n/esc cancel`.
- Pressing `y` triggers the actual backend script (e.g. `remove --yes`). Pressing `n` or `esc` resets the confirmation state.
