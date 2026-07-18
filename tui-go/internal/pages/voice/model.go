package voice

import (
	"encoding/json"
	"fmt"
	"regexp"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"github.com/iamcheyan/oh-my-desktop/tui-go/internal/backend"
	"github.com/iamcheyan/oh-my-desktop/tui-go/internal/ui"
)

type tickMsg time.Time

type recentItem struct {
	Text string `json:"text"`
	Ts   int64  `json:"ts"`
}

const (
	iconMic       = "\uf130" // nf-fa-microphone
	iconStop      = "\uf04d" // nf-fa-stop
	iconDownload  = "\uf019" // nf-fa-download
	iconRefresh   = "\uf021" // nf-fa-refresh
	iconKeyboard  = "\uf11c" // nf-fa-keyboard
	iconWrench    = "\uf0ad" // nf-fa-wrench
	iconClipboard = "\uf328" // nf-fa-clipboard
	iconClear     = "\uf12d" // nf-fa-eraser
)

type Model struct {
	backend  backend.Backend
	status   backend.Status
	bindings []string

	width   int
	height  int
	busy    bool
	err     string
	message string

	recStart time.Time
}

func New(b backend.Backend) Model {
	return Model{backend: b}
}

func (m Model) Init() tea.Cmd {
	return tea.Batch(m.fetchStatus(), tick())
}

func tick() tea.Cmd {
	return tea.Tick(900*time.Millisecond, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
	case tea.MouseMsg:
		if msg.Type == tea.MouseRelease && msg.Button == tea.MouseButtonLeft {
			viewStr := m.View()
			lines := strings.Split(viewStr, "\n")
			if msg.Y >= 0 && msg.Y < len(lines) {
				var ansiRegex = regexp.MustCompile(`\x1b\[[0-9;]*[a-zA-Z]`)
				plain := ansiRegex.ReplaceAllString(lines[msg.Y], "")
				if msg.X >= 0 && msg.X < len(plain) {
					type btn struct {
						text string
						key  string
					}
					buttons := []btn{
						{"Refresh", "r"},
						{"Key tester", "k"},
						{"Edit file", "e"},
						{"Diagnose", "d"},
						{"Test TUI", "t"},
						{"Clear recent", "c"},
						{"Record", "enter"},
						{"Setup", "enter"},
						{"Cancel", "enter"},
						{"Stop", "enter"},
					}
					for _, b := range buttons {
						idx := strings.Index(plain, b.text)
						if idx >= 0 {
							if msg.X >= idx-2 && msg.X <= idx+len(b.text)+2 {
								return m.handleKey(b.key)
							}
						}
					}
				}
			}
		}
	case tickMsg:
		return m, tea.Batch(m.fetchStatus(), tick())
	case backend.StatusMsg:
		if msg.Err != nil {
			m.err = msg.Err.Error()
			return m, nil
		}
		wasRecording := m.recording()
		m.status = msg.Values
		m.err = ""
		if m.recording() && !wasRecording {
			m.recStart = time.Now()
		}
		m.bindings = parseBindings(msg.Values.Raw())
	case backend.ActionMsg:
		m.busy = false
		if msg.Err != nil {
			m.err = msg.Err.Error()
			m.message = "Action failed"
		} else {
			m.err = ""
			m.message = actionMessage(msg.Action)
		}
		return m, m.fetchStatus()
	case tea.KeyMsg:
		return m.handleKey(msg.String())
	}
	return m, nil
}

func (m Model) handleKey(key string) (tea.Model, tea.Cmd) {
	switch key {
	case "q", "ctrl+c", "esc":
		return m, tea.Quit
	case "r":
		return m, m.fetchStatus()
	}
	if m.busy {
		return m, nil
	}

	switch key {
	case "enter", " ":
		switch m.state() {
		case "nomodel":
			m.busy = true
			m.message = "Starting setup..."
			return m, m.runAction("setup")
		case "downloading":
			m.busy = true
			m.message = "Cancelling..."
			return m, m.runAction("cancel")
		case "recording":
			m.busy = true
			m.message = "Transcribing..."
			return m, m.runAction("record-stop")
		default:
			m.busy = true
			m.message = "Recording..."
			return m, m.runAction("record-start")
		}
	case "s":
		m.busy = true
		m.message = "Starting setup..."
		return m, m.runAction("setup")
	case "t":
		m.busy = true
		return m, m.runAction("test")
	case "d":
		m.busy = true
		return m, m.runAction("diagnose")
	case "e":
		m.busy = true
		return m, m.runAction("edit")
	case "k":
		m.busy = true
		return m, m.runAction("key-test")
	case "c":
		if len(m.recentItems()) > 0 {
			m.busy = true
			return m, m.runAction("recent-clear")
		}
	}
	return m, nil
}

func (m Model) View() string {
	if m.width <= 0 || m.height <= 0 {
		return "Initializing..."
	}

	contentW := max(16, m.width-2)
	fixedRows := 2
	if m.message != "" || m.err != "" || m.busy {
		fixedRows++
	}
	contentH := max(12, m.height-fixedRows-2)

	content := ui.PreserveBackground(ui.FitBlock(m.contentView(contentW, contentH), contentW, contentH), ui.Background)
	help := ui.HelpText(
		ui.HelpItem("enter", m.primaryHelp()),
		ui.HelpItem("s", "setup"),
		ui.HelpItem("e", "bindings"),
		ui.HelpItem("k", "key tester"),
		ui.HelpItem("d", "diagnose"),
		ui.HelpItem("t", "test tui"),
		ui.HelpItem("r", "refresh"),
		ui.HelpItem("q", "quit"),
	)

	parts := []string{content, help}
	if status := m.statusLine(); status != "" {
		parts = append([]string{status}, parts...)
	}
	return ui.Screen.Padding(1, 1).Render(lipgloss.JoinVertical(lipgloss.Left, parts...))
}

func (m Model) contentView(width, height int) string {
	if m.status == nil {
		return "Loading..."
	}

	heroH := 11
	if width < 82 {
		heroH = 18
	}
	remaining := max(4, height-heroH-1)
	top := m.heroView(width)
	body := m.bodyView(width, remaining)
	return strings.Join([]string{top, "", body}, "\n")
}

func (m Model) heroView(width int) string {
	previewW := 22
	infoW := width - previewW - 3
	if infoW < 48 {
		return strings.Join([]string{
			m.voicePreview(previewW, 8),
			m.statusInfo(width),
			m.primaryButtons(width),
		}, "\n")
	}
	return lipgloss.JoinHorizontal(lipgloss.Top,
		m.voicePreview(previewW, 8),
		"   ",
		strings.Join([]string{
			m.statusInfo(infoW),
			"",
			m.primaryButtons(infoW),
		}, "\n"),
	)
}

func (m Model) voicePreview(width, height int) string {
	width = max(18, width)
	height = max(7, height)
	innerW := max(12, width-4)
	pal := m.tone()
	state := m.stateLabel()
	level := lipgloss.NewStyle().Background(pal).Foreground(ui.Background).Width(innerW).Render(" " + m.stateMarker())
	icon := lipgloss.NewStyle().Foreground(pal).Bold(true).Width(innerW).Render(" " + iconMic + "  Voice")
	line := lipgloss.NewStyle().Foreground(ui.Muted).Width(innerW).Render(" " + ui.TruncatePlain(state, max(1, innerW-2)))
	fillRows := max(1, height-5)
	fills := make([]string, 0, fillRows)
	for i := 0; i < fillRows; i++ {
		fills = append(fills, lipgloss.NewStyle().Background(ui.Background).Width(innerW).Render(" "))
	}
	wave := lipgloss.NewStyle().Foreground(pal).Width(innerW).Render(" " + recordingWave(m.recording()))
	rows := append([]string{level, icon, line}, fills...)
	rows = append(rows, wave)
	return lipgloss.NewStyle().
		Border(lipgloss.ThickBorder()).
		BorderForeground(ui.LineSoft).
		Background(ui.Background).
		Padding(0, 1).
		Render(strings.Join(rows, "\n"))
}

func (m Model) statusInfo(width int) string {
	model := "missing"
	if m.bool("modelReady") {
		model = "SenseVoice Small"
	}
	venv := "missing"
	if m.bool("venvReady") {
		venv = "ready"
	}
	daemon := "idle"
	if m.bool("daemonRunning") {
		daemon = "running"
	}

	lines := []string{
		ui.Title.Render("Voice Input"),
		ui.MutedText.Render(ui.TruncateStyled("Speech-to-text model, microphone test, and helper tools.", width)),
		"",
		m.row("State", m.stateLabel(), width),
		m.row("Model", model, width),
		m.row("Size", m.value("modelSizeMB", "0")+" MB", width),
		m.row("Venv", venv, width),
		m.row("Daemon", daemon, width),
	}
	if m.state() == "downloading" {
		lines = append(lines, "", m.downloadView(width))
	}
	return strings.Join(lines, "\n")
}

func (m Model) primaryButtons(width int) string {
	active := m.recording()
	label := "Record"
	key := "enter"
	icon := iconMic
	switch m.state() {
	case "nomodel":
		label = "Setup"
		icon = iconDownload
	case "downloading":
		label = "Cancel"
		icon = iconStop
	case "recording":
		label = "Stop"
		icon = iconStop
	}
	buttons := []string{
		ui.ActionButton(icon, key, label, active),
		ui.ActionButton(iconRefresh, "r", "Refresh", false),
	}
	if width < 40 {
		return lipgloss.JoinVertical(lipgloss.Left,
			buttons[0],
			buttons[1],
		)
	}
	return lipgloss.JoinHorizontal(lipgloss.Top, buttons...)
}

func (m Model) bodyView(width, height int) string {
	if width < 90 {
		return lipgloss.JoinVertical(lipgloss.Left,
			m.bindingsView(width, max(6, height/2)),
			"",
			m.recentAndToolsView(width, max(6, height/2)),
		)
	}
	leftW := max(36, width/2-2)
	rightW := width - leftW - 3
	left := ui.PreserveBackground(ui.FitBlock(m.bindingsView(leftW, height), leftW, height), ui.Background)
	right := ui.PreserveBackground(ui.FitBlock(m.recentAndToolsView(rightW, height), rightW, height), ui.Background)
	return lipgloss.JoinHorizontal(lipgloss.Top, left, "   ", right)
}

func (m Model) bindingsView(width, height int) string {
	lines := []string{
		ui.Section.Render("Bindings"),
		ui.MutedText.Render(ui.TruncateStyled("Runtime uses Hyprland bindings. Edit the file when you need custom triggers.", width)),
		"",
	}
	binds := m.bindings
	if len(binds) == 0 {
		binds = []string{m.value("defaultTrigger", "ALT + A")}
		lines = append(lines, ui.SubtleText.Render("Using defaults"))
	}
	for i, raw := range binds {
		if len(lines) >= height-4 {
			lines = append(lines, ui.SubtleText.Render(fmt.Sprintf("... %d more", len(binds)-i)))
			break
		}
		lines = append(lines,
			lipgloss.NewStyle().Foreground(ui.Text).Render(ui.TruncateStyled("  "+friendly(raw), width)),
			ui.SubtleText.Render(ui.TruncateStyled("  "+raw, width)),
		)
	}
	lines = append(lines, "",
		lipgloss.JoinHorizontal(lipgloss.Top,
			ui.ActionButton(iconKeyboard, "k", "Key tester", false),
			ui.ActionButton(iconKeyboard, "e", "Edit file", false),
		),
	)
	lines = append(lines, ui.SubtleText.Render(ui.TruncateStyled(ui.ShortPath(m.value("bindingsFile", "-")), width)))
	return strings.Join(lines, "\n")
}

func (m Model) recentAndToolsView(width, height int) string {
	lines := []string{
		ui.Section.Render("Recent"),
	}
	items := m.recentItems()
	if len(items) == 0 {
		lines = append(lines, ui.SubtleText.Render(ui.TruncateStyled("No transcriptions yet. Press enter to test.", width)))
	} else {
		for i, item := range items {
			if len(lines) >= height-7 {
				lines = append(lines, ui.SubtleText.Render(fmt.Sprintf("... %d more", len(items)-i)))
				break
			}
			lines = append(lines, ui.TruncateStyled("  "+item.Text, width))
		}
	}
	lines = append(lines,
		"",
		ui.Section.Render("Tools"),
		lipgloss.JoinHorizontal(lipgloss.Top,
			ui.ActionButton(iconWrench, "d", "Diagnose", false),
			ui.ActionButton(iconClipboard, "t", "Test TUI", false),
		),
		ui.ActionButton(iconClear, "c", "Clear recent", false),
		"",
		ui.Section.Render("Paths"),
		m.row("Model", ui.ShortPath(m.value("modelDir", "-")), width),
		m.row("Socket", m.value("socket", "-"), width),
		m.row("Cache", ui.ShortPath(m.value("cacheDir", "-")), width),
	)
	return strings.Join(lines, "\n")
}

func (m Model) downloadView(width int) string {
	percent := ui.ParseInt(m.value("download.percent", "0"))
	label := m.value("download.label", "model")
	speed := speedLabel(m.value("download.speedBps", "0"))
	eta := etaLabel(m.value("download.etaSec", "0"))
	barW := max(10, min(34, width-10))
	return strings.Join([]string{
		ui.WarnText.Render("Downloading " + label),
		ui.ProgressBar(percent, barW) + " " + fmt.Sprintf("%d%%", percent),
		m.row("Speed", speed, width),
		m.row("Remaining", eta, width),
	}, "\n")
}

func (m Model) statusLine() string {
	parts := []string{}
	if m.busy {
		parts = append(parts, ui.OKText.Render("working..."))
	}
	if m.err != "" {
		parts = append(parts, ui.DangerText.Render(m.err))
	}
	if m.message != "" && !m.busy {
		parts = append(parts, ui.OKText.Render(m.message))
	}
	return strings.Join(parts, " ")
}

func (m Model) fetchStatus() tea.Cmd {
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-voice", "status")
		if result.Err != nil {
			return backend.StatusMsg{Err: result.Err}
		}
		return backend.StatusMsg{Values: backend.ParseStatus(result.Lines)}
	}
}

func (m Model) runAction(action string) tea.Cmd {
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-voice", action)
		return backend.ActionMsg{Action: action, Err: result.Err}
	}
}

func (m Model) value(key, fallback string) string {
	return m.status.Value(key, fallback)
}

func (m Model) bool(key string) bool {
	return m.status.Bool(key)
}

func (m Model) state() string {
	return m.status.Value("state", "idle")
}

func (m Model) recording() bool {
	return m.state() == "recording"
}

// stateMeta drives the static per-state presentation. stateLabel stays a
// method because recording appends a live timer and idle can become "Ready".
var stateMeta = map[string]struct {
	label  string
	marker string
	help   string
	tone   lipgloss.Color
}{
	"nomodel":     {"Needs setup", "Setup", "setup", ui.Warn},
	"downloading": {"Installing", "Install", "cancel", ui.Warn},
	"recording":   {"Recording", "Live", "stop", ui.Danger},
	"idle":        {"Ready", "Ready", "record", ui.Accent},
}

func (m Model) stateLabel() string {
	switch m.state() {
	case "recording":
		if !m.recStart.IsZero() {
			return "Recording " + ui.FormatDuration(int(time.Since(m.recStart).Seconds()))
		}
		return "Recording"
	case "idle":
		if m.bool("modelReady") && m.bool("venvReady") {
			return "Ready"
		}
		return "Idle"
	default:
		if meta, ok := stateMeta[m.state()]; ok {
			return meta.label
		}
		return m.state()
	}
}

func (m Model) stateMarker() string {
	return stateMeta[m.state()].marker
}

func (m Model) primaryHelp() string {
	return stateMeta[m.state()].help
}

func (m Model) tone() lipgloss.Color {
	return stateMeta[m.state()].tone
}

func (m Model) row(label, value string, width int) string {
	labelW := min(12, max(6, width/4))
	valueW := max(1, width-labelW-1)
	l := lipgloss.NewStyle().Foreground(ui.Text).Width(labelW).Render(label)
	v := lipgloss.NewStyle().Foreground(ui.Muted).Width(valueW).Align(lipgloss.Right).Render(ui.TruncatePlain(value, valueW))
	return l + " " + v
}

func (m Model) recentItems() []recentItem {
	raw := strings.TrimSpace(m.value("recent", "[]"))
	if raw == "" || raw == "[]" {
		return nil
	}
	var items []recentItem
	if err := json.Unmarshal([]byte(raw), &items); err != nil {
		return nil
	}
	return items
}

func parseBindings(raw string) []string {
	var binds []string
	for _, line := range strings.Split(raw, "\n") {
		if v, ok := strings.CutPrefix(line, "binding="); ok {
			v = strings.TrimSpace(v)
			if v != "" {
				binds = append(binds, v)
			}
		}
	}
	return binds
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

func actionMessage(action string) string {
	switch action {
	case "setup":
		return "Setup started"
	case "cancel":
		return "Setup cancelled"
	case "record-start":
		return "Recording started"
	case "record-stop":
		return "Transcription finished"
	case "test":
		return "Test tool opened"
	case "diagnose":
		return "Diagnose opened"
	case "edit":
		return "Binding file opened"
	case "bind-tui":
		return "Binding tool opened"
	case "key-test":
		return "Key tester opened"
	case "capture":
		return "Captured key added"
	case "recent-clear":
		return "Recent history cleared"
	}
	return action + " done"
}

func recordingWave(active bool) string {
	if !active {
		return "▁▁▁▁▁▁▁"
	}
	return "▂▆█▆▂▆█"
}

func speedLabel(raw string) string {
	n := ui.ParseInt(raw)
	if n <= 0 {
		return "-"
	}
	if n >= 1024*1024 {
		return fmt.Sprintf("%.1f MB/s", float64(n)/(1024*1024))
	}
	return fmt.Sprintf("%.0f KB/s", float64(n)/1024)
}

func etaLabel(raw string) string {
	sec := ui.ParseInt(raw)
	if sec <= 0 {
		return "-"
	}
	if sec >= 3600 {
		return fmt.Sprintf("%dh%02dm", sec/3600, (sec%3600)/60)
	}
	return fmt.Sprintf("%dm%02ds", sec/60, sec%60)
}
