package voice

import (
	"fmt"
	"os"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"github.com/iamcheyan/oh-my-desktop/tui-go/internal/backend"
	"github.com/iamcheyan/oh-my-desktop/tui-go/internal/ui"
)

type status map[string]string

type statusMsg struct {
	values status
	err    error
}

type actionMsg struct {
	action string
	lines  []string
	err    error
}

type Model struct {
	backend  backend.Backend
	status   status
	width    int
	height   int
	busy     bool
	err      string
	message  string
	selected int
	bindings []string
}

var friendlyMap = map[string]string{
	"ALT + A":      "Alt + A",
	"code:472":     "Globe (Fn)",
	"XF86Tools":    "F13 / Tools",
	"TOOLS":        "F13 / Tools",
	"0X100811D0":   "Hangul / Hanja",
	"0x100811D0":   "Hangul / Hanja",
	"escape":       "Esc",
	"ESCAPE":       "Esc",
	"HANGUL_HANJA": "Hangul / Hanja",
}

func friendly(raw string) string {
	raw = strings.TrimSpace(raw)
	if v, ok := friendlyMap[raw]; ok {
		return v
	}
	repl := strings.NewReplacer(
		"ALT", "Alt", "CTRL", "Ctrl", "CONTROL", "Ctrl",
		"SUPER", "Super", "SHIFT", "Shift", "MOD", "Mod",
	)
	return repl.Replace(raw)
}

func New(b backend.Backend) Model {
	return Model{backend: b, selected: 0}
}

func (m Model) Init() tea.Cmd {
	return m.fetchStatus()
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c", "esc":
			return m, tea.Quit
		case "up", "k":
			if m.selected > 0 {
				m.selected--
			}
		case "down", "j":
			if m.selected < len(m.bindings)-1 {
				m.selected++
			}
		case "r":
			return m, m.fetchStatus()
		case "s":
			if !m.busy {
				m.busy = true
				return m, m.runAction("setup")
			}
		case "n":
			if !m.busy {
				m.busy = true
				return m, m.runAction("capture")
			}
		case "e":
			if !m.busy {
				m.busy = true
				return m, m.runAction("edit")
			}
		case "d":
			if !m.busy {
				m.busy = true
				return m, m.runAction("diagnose")
			}
		case "t":
			if !m.busy {
				m.busy = true
				return m, m.runAction("test")
			}
		case "c":
			if !m.busy && len(m.bindings) > 0 {
				raw := m.bindings[m.selected]
				m.busy = true
				return m, m.removeBinding(raw)
			}
		case "enter", "a":
			if !m.busy {
				needs := m.needsSetup()
				m.busy = true
				if needs {
					return m, m.runAction("setup")
				}
				return m, m.runAction("record")
			}
		}
	case statusMsg:
		if msg.err != nil {
			m.err = msg.err.Error()
		} else {
			m.status = msg.values
			m.err = ""
			var binds []string
			for _, l := range strings.Split(msg.values["__raw__"], "\n") {
				if strings.HasPrefix(l, "binding=") {
					binds = append(binds, strings.TrimPrefix(l, "binding="))
				}
			}
			m.bindings = binds
			if m.selected >= len(m.bindings) {
				m.selected = len(m.bindings) - 1
			}
			if m.selected < 0 {
				m.selected = 0
			}
		}
	case actionMsg:
		m.busy = false
		if msg.err != nil {
			m.err = msg.err.Error()
			m.message = "Action failed"
		} else {
			m.message = actionMessage(msg)
		}
		return m, m.fetchStatus()
	}
	return m, nil
}

func (m Model) View() string {
	if m.width <= 0 || m.height <= 0 {
		return "Initializing..."
	}
	width := m.width
	height := m.height

	const (
		screenPaddingX = 4
		screenPaddingY = 2
		panelBorderW   = 2
		panelBorderH   = 2
		panelPadW      = 4
		panelPadH      = 2
		fixedRows      = 2
	)

	panelInnerW := width - screenPaddingX - panelBorderW*2 - panelPadW*2
	if panelInnerW < 20 {
		panelInnerW = 20
	}
	panelInnerH := height - screenPaddingY - fixedRows - panelBorderH - panelPadH
	if panelInnerH < 8 {
		panelInnerH = 8
	}
	panelBoxW := panelInnerW + panelPadW
	panelBoxH := panelInnerH + panelPadH

	header := ui.Title.Render("Voice input") + " " + ui.MutedText.Render("Go settings TUI")
	if m.busy {
		header += " " + ui.OKText.Render("working...")
	}
	if m.err != "" {
		header += " " + ui.DangerText.Render(m.err)
	}
	if m.message != "" && !m.busy {
		header += " " + ui.OKText.Render(m.message)
	}

	body := ui.PanelBox.Width(panelBoxW).Height(panelBoxH).Render(
		ui.PreserveBackground(ui.FitBlock(m.bodyView(panelInnerW), panelInnerW, panelInnerH), ui.Panel),
	)

	help := ui.SubtleText.Render("enter/a test · n add key · e edit bindings · c remove · d diagnose · s setup · r refresh · q quit")
	if m.busy {
		help = ui.OKText.Render("working...")
	}

	return ui.Screen.Padding(1, 2).Render(
		lipgloss.JoinVertical(lipgloss.Left,
			header,
			body,
			help,
		),
	)
}

func (m Model) bodyView(width int) string {
	if m.status == nil {
		return "Loading..."
	}

	health := m.healthTitle()
	detail := m.healthDetail()

	label := "Record"
	if m.needsSetup() {
		label = "Setup"
	}

	lines := []string{
		ui.Title.Render("Voice input"),
		ui.TruncateStyled(fmt.Sprintf("%s · %s", health, detail), width),
		"",
		ui.Section.Render("Trial record"),
		ui.MutedText.Render(ui.TruncateStyled(m.trialHint(), width)),
		"",
		m.actionButtons(label),
		"",
		ui.Section.Render("Keybindings"),
	}

	if len(m.bindings) == 0 {
		lines = append(lines,
			ui.MutedText.Render(ui.TruncateStyled("Using default trigger: Alt + A", width)),
		)
	} else {
		for i, raw := range m.bindings {
			cursor := "  "
			style := lipgloss.NewStyle().Foreground(ui.Text)
			if i == m.selected {
				cursor = ui.OKText.Render("▶ ")
				style = style.Bold(true)
			}
			line := style.Render(ui.TruncateStyled(fmt.Sprintf("%s%s", cursor, friendly(raw)), width-10))
			lines = append(lines, line+ui.SubtleText.Render("  c remove"))
		}
	}

	lines = append(lines,
		"",
		ui.SubtleText.Render(ui.TruncateStyled("n captures a new global trigger · e opens the full binding editor", width)),
		"",
		ui.Section.Render("Model & engine"),
		ui.Row("Model", m.modelLabel(), width),
		ui.Row("Venv", readyText(m.bool("venvReady")), width),
		ui.Row("Daemon", daemonText(m.bool("daemonRunning")), width),
		"",
		ui.Section.Render("Advanced"),
		ui.Row("Cache", shortPath(m.value("cacheDir", "-")), width),
		ui.Row("Model dir", shortPath(m.value("modelDir", "-")), width),
		ui.Row("Venv", shortPath(m.value("venvDir", "-")), width),
		ui.Row("Socket", m.value("socket", "/tmp/omd-voice.sock"), width),
		ui.Row("Bindings", shortPath(m.value("bindingsFile", "-")), width),
		ui.MutedText.Render(ui.TruncateStyled("d diagnose · t open test tool", width)),
	)

	return strings.Join(lines, "\n")
}

func (m Model) actionButtons(label string) string {
	var primary string
	if m.busy {
		primary = ui.DisabledButton.Render("enter " + label)
	} else {
		primary = ui.PrimaryButton.Render("enter " + label)
	}
	setupBtn := ui.Button.Render("s Setup")
	if m.busy {
		setupBtn = ui.DisabledButton.Render("s Setup")
	}
	refreshBtn := ui.Button.Render("r Refresh")
	if m.busy {
		refreshBtn = ui.DisabledButton.Render("r Refresh")
	}
	addBtn := ui.Button.Render("n Add key")
	diagBtn := ui.Button.Render("d Diagnose")
	if m.busy {
		addBtn = ui.DisabledButton.Render("n Add key")
		diagBtn = ui.DisabledButton.Render("d Diagnose")
	}
	return lipgloss.JoinHorizontal(lipgloss.Top, primary, setupBtn, addBtn, diagBtn, refreshBtn)
}

func (m Model) needsSetup() bool {
	return m.value("state", "") == "setup" || m.value("modelSizeMB", "0") == "0"
}

func (m Model) healthTitle() string {
	if m.needsSetup() {
		return "Needs setup"
	}
	return "Ready"
}

func (m Model) healthDetail() string {
	modelPart := "Model missing"
	if mb := m.value("modelSizeMB", "0"); mb != "0" {
		modelPart = fmt.Sprintf("SenseVoice · %s MB", mb)
	}
	daemonPart := "daemon idle"
	if m.bool("daemonRunning") {
		daemonPart = "daemon running"
	}
	if m.needsSetup() {
		return modelPart + " · run setup to enable voice input"
	}
	return modelPart + " · " + daemonPart
}

func (m Model) trialHint() string {
	if m.needsSetup() {
		return "Install the engine first, then try a short phrase here."
	}
	return "Record a short phrase to verify mic, model, and paste."
}

func (m Model) fetchStatus() tea.Cmd {
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-voice", "status")
		if result.Err != nil {
			return statusMsg{err: result.Err}
		}
		values := backend.ParseKV(result.Lines)
		values["__raw__"] = strings.Join(result.Lines, "\n")
		return statusMsg{values: values}
	}
}

func (m Model) runAction(action string) tea.Cmd {
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-voice", action)
		return actionMsg{action: action, lines: result.Lines, err: result.Err}
	}
}

func (m Model) removeBinding(raw string) tea.Cmd {
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-voice", "remove", raw)
		return actionMsg{action: "remove " + raw, lines: result.Lines, err: result.Err}
	}
}

func (m Model) value(key, fallback string) string {
	if m.status == nil {
		return fallback
	}
	if v := m.status[key]; v != "" {
		return v
	}
	return fallback
}

func (m Model) bool(key string) bool {
	return m.value(key, "false") == "true"
}

func (m Model) modelLabel() string {
	if !m.bool("modelReady") {
		return "missing"
	}
	if mb := m.value("modelSizeMB", "0"); mb != "0" {
		return "SenseVoice · " + mb + " MB"
	}
	return "ready"
}

func readyText(ready bool) string {
	if ready {
		return "ready"
	}
	return "missing"
}

func daemonText(running bool) string {
	if running {
		return "running"
	}
	return "idle"
}

func shortPath(path string) string {
	path = strings.TrimSpace(path)
	home, _ := os.UserHomeDir()
	home = strings.TrimSpace(home)
	if home != "" && strings.HasPrefix(path, home+"/") {
		return "~/" + strings.TrimPrefix(path, home+"/")
	}
	return path
}

func actionMessage(msg actionMsg) string {
	for _, line := range msg.lines {
		if value, ok := strings.CutPrefix(line, "captured="); ok && strings.TrimSpace(value) != "" {
			return "Added " + friendly(value)
		}
		if value, ok := strings.CutPrefix(line, "result="); ok && strings.TrimSpace(value) != "" {
			switch strings.TrimSpace(value) {
			case "editor-opened":
				return "Binding editor opened"
			case "diagnose-opened":
				return "Diagnose opened"
			case "test-opened":
				return "Test tool opened"
			case "setup-done":
				return "Setup complete"
			case "removed":
				return "Binding removed"
			case "added":
				return "Binding added"
			}
		}
	}
	return "Done"
}
