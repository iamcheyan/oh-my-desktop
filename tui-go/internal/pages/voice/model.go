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

type logsMsg struct {
	lines []string
	err   error
}

type actionLogMsg struct {
	action string
	lines  []string
	err    error
}

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

	// Logs and scroll view matching Windows VM settings page
	logs          []string
	scrollOffset  int
	confirmRemove bool
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
		if msg.Type == tea.MouseWheelUp {
			m.scrollOffset++
			return m, nil
		}
		if msg.Type == tea.MouseWheelDown {
			if m.scrollOffset > 0 {
				m.scrollOffset--
			}
			return m, nil
		}
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
						{"Refresh status", "r"},
						{"Key tester", "k"},
						{"Edit bindings file", "e"},
						{"Diagnose", "d"},
						{"Clear recent", "c"},
						{"Re-run setup", "s"},
						{"Record", "enter"},
						{"Setup voice input", "enter"},
						{"Cancel setup", "enter"},
						{"Stop & transcribe", "enter"},
						{"Delete model", "x"},
						{"Confirm delete? y", "y"},
						{"n (no)", "n"},
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
		cmds := []tea.Cmd{m.fetchStatus(), tick()}
		if m.state() == "downloading" {
			cmds = append(cmds, m.fetchLogs())
		}
		return m, tea.Batch(cmds...)
	case logsMsg:
		if msg.err == nil {
			m.logs = msg.lines
		}
		return m, nil
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
	case actionLogMsg:
		m.busy = false
		if msg.err != nil {
			m.err = msg.err.Error()
			m.message = "Action failed"
		} else {
			m.err = ""
			m.message = actionMessage(msg.action)
		}
		// Append action execution with stdout lines directly to console logs
		m.logs = append(m.logs, "$ "+msg.action)
		m.logs = append(m.logs, msg.lines...)
		m.logs = ui.ClipLines(m.logs, 140)
		return m, m.fetchStatus()
	case tea.KeyMsg:
		return m.handleKey(msg.String())
	}
	return m, nil
}

func (m Model) handleKey(key string) (tea.Model, tea.Cmd) {
	if m.confirmRemove {
		switch key {
		case "y", "Y":
			m.confirmRemove = false
			m.busy = true
			m.message = "Deleting model..."
			return m, m.runAction("delete-model")
		case "n", "N", "esc":
			m.confirmRemove = false
			return m, nil
		}
		return m, nil
	}

	switch key {
	case "q", "ctrl+c", "esc":
		return m, tea.Quit
	case "r":
		return m, m.fetchStatus()
	case "up", "k":
		m.scrollOffset++
		return m, nil
	case "down", "j":
		if m.scrollOffset > 0 {
			m.scrollOffset--
		}
		return m, nil
	case "pageup":
		m.scrollOffset += 10
		return m, nil
	case "pagedown":
		if m.scrollOffset > 10 {
			m.scrollOffset -= 10
		} else {
			m.scrollOffset = 0
		}
		return m, nil
	case "home":
		m.scrollOffset = 999999
		return m, nil
	case "end":
		m.scrollOffset = 0
		return m, nil
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
	case "d":
		m.busy = true
		return m, m.runAction("diagnose")
	case "t":
		m.busy = true
		return m, m.runAction("test")
	case "e":
		m.busy = true
		return m, m.runAction("edit")
	case "k":
		m.busy = true
		return m, m.runAction("key-test")
	case "x":
		if m.bool("modelReady") {
			m.confirmRemove = true
		}
		return m, nil
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
	fixedRows := 1 // help
	if m.statusLine() != "" {
		fixedRows++
	}
	contentH := max(12, m.height-fixedRows-2)

	content := ui.PreserveBackground(ui.FitBlock(m.mainPanel(contentW, contentH), contentW, contentH), ui.Background)

	var helpText string
	if m.confirmRemove {
		helpText = ui.HelpText(ui.HelpItem("y", "confirm delete"), ui.HelpItem("n/esc", "cancel"))
	} else {
		helpText = ui.HelpText(m.helpItems()...)
	}

	parts := []string{content, helpText}
	if status := m.statusLine(); status != "" {
		parts = append([]string{status}, parts...)
	}
	return ui.Screen.Padding(1, 1).Render(lipgloss.JoinVertical(lipgloss.Left, parts...))
}

func (m Model) mainPanel(width, height int) string {
	if m.status == nil {
		return "Loading..."
	}

	if width >= 90 {
		leftW := min(54, max(38, width/3))
		rightW := width - leftW - 2
		if rightW < 40 {
			rightW = 40
			leftW = max(28, width-2-rightW)
		}
		left := ui.PreserveBackground(ui.FitBlock(m.controlView(leftW), leftW, height), ui.Background)
		right := ui.PreserveBackground(ui.FitBlock(m.rightPaneView(rightW, height), rightW, height), ui.Background)
		return lipgloss.JoinHorizontal(lipgloss.Top, left, "  ", right)
	}

	left := m.controlView(width)
	right := m.rightPaneView(width, max(8, height/2))
	return left + "\n\n" + right
}

func (m Model) controlView(width int) string {
	health := m.stateLabel()
	title := m.statusLight() + " " + ui.Title.Render("Voice Input")
	if m.busy {
		title += " " + ui.OKText.Render("working…")
	}

	daemon := "idle"
	if m.bool("daemonRunning") {
		daemon = "running"
	}
	size := m.value("modelSizeMB", "0")
	subtitle := fmt.Sprintf("%s · SenseVoice · %s MB · daemon %s", health, size, daemon)
	if !m.bool("modelReady") {
		subtitle = fmt.Sprintf("%s · SenseVoice · Model missing", health)
	}

	lines := []string{
		title,
		ui.MutedText.Render(ui.TruncateStyled(subtitle, width)),
		"",
		m.modelBox(width),
		"",
	}

	if m.bool("modelReady") {
		recordLabel := "Record"
		if m.recording() {
			recordLabel = "Stop & transcribe"
		}
		lines = append(lines,
			m.sectionTitle("TRIAL RECORD"),
			ui.MutedText.Render("Test the mic and paste pipeline from this panel."),
			m.actionPrimary(recordLabel, true, width),
			"",
		)

		lines = append(lines,
			m.sectionTitle("BINDINGS"),
			ui.MutedText.Render(ui.TruncateStyled("Primary trigger first. Esc cancels while recording.", width)),
		)
		binds := m.bindings
		if len(binds) == 0 {
			binds = []string{m.value("defaultTrigger", "ALT + A")}
			lines = append(lines, ui.SubtleText.Render("  Using defaults"))
		}
		for i, raw := range binds {
			prefix := "  · "
			if i == 0 {
				prefix = "  ★ "
				lines = append(lines, lipgloss.NewStyle().Foreground(ui.Accent).Bold(true).Render(ui.TruncatePlain(prefix+friendly(raw), width)))
			} else {
				lines = append(lines, lipgloss.NewStyle().Foreground(ui.Text).Render(ui.TruncatePlain(prefix+friendly(raw), width)))
			}
		}
		lines = append(lines,
			m.actionSecondary("e", "Edit bindings file", true),
			m.actionSecondary("k", "Key tester", true),
			ui.SubtleText.Render("  "+ui.ShortPath(m.value("bindingsFile", "-"))),
			"",
		)

		lines = append(lines,
			m.sectionTitle("ADVANCED"),
			m.actionSecondary("d", "Diagnose", true),
			m.actionSecondary("t", "Test TUI", true),
			m.actionSecondary("s", "Re-run setup", true),
			"",
		)
	} else {
		lines = append(lines,
			m.sectionTitle("ADVANCED"),
			m.actionSecondary("d", "Diagnose", true),
			"",
		)
	}

	return strings.Join(lines, "\n")
}

type palette struct {
	background lipgloss.Color
	line       lipgloss.Color
}

func (m Model) palette() palette {
	return palette{
		background: ui.Panel,
		line:       ui.Accent,
	}
}

func (m Model) modelBox(width int) string {
	pal := m.palette()
	boxW := width
	if boxW < 20 {
		boxW = 20
	}
	innerW := boxW - 4

	var statusLines []string
	statusLines = append(statusLines, m.sectionTitle("MODEL SPECIFICATIONS"))
	statusLines = append(statusLines, m.kvLine("Engine", "SenseVoice Small INT8", innerW))
	statusLines = append(statusLines, m.kvLine("Size", m.value("modelSizeMB", "0")+" MB", innerW))
	statusLines = append(statusLines, m.kvLine("Venv", boolReady(m.bool("venvReady")), innerW))
	statusLines = append(statusLines, m.kvLine("Daemon", boolRunning(m.bool("daemonRunning")), innerW))

	var actionText string
	if m.confirmRemove {
		actionText = lipgloss.NewStyle().Foreground(ui.Danger).Bold(true).Render("  Confirm delete? y (yes) / n (no)")
	} else if m.bool("modelReady") {
		actionText = m.actionSecondary("x", "Delete model", true)
	} else {
		actionText = m.actionPrimary("Setup voice input", true, innerW)
	}
	statusLines = append(statusLines, "", actionText)

	boxContent := strings.Join(statusLines, "\n")

	return lipgloss.NewStyle().
		Border(lipgloss.ThickBorder()).
		BorderForeground(pal.line).
		Background(pal.background).
		Padding(1, 2).
		Width(boxW).
		Render(boxContent)
}

func (m Model) rightPaneView(width, height int) string {
	state := m.state()

	if state == "downloading" {
		percent := ui.ParseInt(m.value("download.percent", "0"))
		label := m.value("download.label", "model")
		if label == "" {
			label = "model"
		}
		speed := speedLabel(m.value("download.speedBps", "0"))
		eta := etaLabel(m.value("download.etaSec", "0"))
		barW := max(10, min(40, width-8))

		progressBlock := strings.Join([]string{
			m.sectionTitle("PROGRESS"),
			ui.WarnText.Render("Downloading " + label),
			ui.ProgressBar(percent, barW) + " " + fmt.Sprintf("%d%%", percent),
			m.kvLine("Speed", speed, width),
			m.kvLine("Remaining", eta, width),
			m.actionPrimary("Cancel setup", true, width),
		}, "\n")

		progH := strings.Count(progressBlock, "\n") + 1
		logH := height - progH - 2
		if logH < 3 {
			logH = 3
		}

		logHeader := m.sectionTitle("SETUP LOG OUTPUT")
		logBody := m.logBody(width, logH)

		return progressBlock + "\n\n" + logHeader + "\n" + logBody
	}

	if !m.bool("modelReady") {
		welcomeLines := []string{
			m.sectionTitle("GET STARTED"),
			ui.MutedText.Render(ui.TruncatePlain("Welcome to Voice Input setup.", width)),
			"",
			ui.MutedText.Render(ui.TruncatePlain("This feature enables you to dictate text using local", width)),
			ui.MutedText.Render(ui.TruncatePlain("speech recognition. All audio processing is done entirely", width)),
			ui.MutedText.Render(ui.TruncatePlain("on your device — no external network requests are made.", width)),
			"",
			ui.MutedText.Render(ui.TruncatePlain("Setup will download the SenseVoice model (~229 MB) and", width)),
			ui.MutedText.Render(ui.TruncatePlain("prepare the Python virtual environment.", width)),
			"",
			ui.MutedText.Render(ui.TruncatePlain("To begin, select 'Setup voice input' on the left.", width)),
		}

		welcomeBlock := strings.Join(welcomeLines, "\n")
		welcomeH := strings.Count(welcomeBlock, "\n") + 1
		logH := height - welcomeH - 2
		if logH < 3 {
			logH = 3
		}

		logHeader := m.sectionTitle("CONSOLE LOGS")
		logBody := m.logBody(width, logH)

		return welcomeBlock + "\n\n" + logHeader + "\n" + logBody
	}

	logHeader := m.sectionTitle("LIVE DIAGNOSTICS & LOGS")

	recentLines := []string{}
	items := m.recentItems()
	if len(items) > 0 {
		recentLines = append(recentLines, "", m.sectionTitle("RECENT TRANSCRIPTIONS"))
		for i, item := range items {
			if i >= 3 {
				recentLines = append(recentLines, ui.SubtleText.Render(fmt.Sprintf("  … %d more", len(items)-i)))
				break
			}
			recentLines = append(recentLines, ui.MutedText.Render(ui.TruncatePlain("  "+item.Text, width)))
		}
		recentLines = append(recentLines, m.actionSecondary("c", "Clear recent", true))
	}

	recentH := len(recentLines)
	logH := height - recentH - 2
	if logH < 3 {
		logH = 3
	}

	logBody := m.logBody(width, logH)

	rightBlock := logHeader + "\n" + logBody
	if len(recentLines) > 0 {
		rightBlock += "\n" + strings.Join(recentLines, "\n")
	}
	return rightBlock
}

func (m Model) logBody(width, logCount int) string {
	logWidth := width - 2
	if logWidth < 8 {
		logWidth = 8
	}
	var wrappedLogs []string
	for _, logLine := range m.logs {
		wrappedLogs = append(wrappedLogs, ui.WrapStyled(logLine, logWidth)...)
	}

	totalLines := len(wrappedLogs)
	displayedLogs := make([]string, logCount)

	if totalLines == 0 {
		for i := 0; i < logCount; i++ {
			if i == 0 {
				displayedLogs[i] = ui.SubtleText.Render(ui.PadPlain("No log output yet.", logWidth)) + "  "
			} else {
				displayedLogs[i] = strings.Repeat(" ", logWidth) + "  "
			}
		}
	} else if totalLines <= logCount {
		for i := 0; i < logCount; i++ {
			if i < totalLines {
				padded := ui.PadPlain(wrappedLogs[i], logWidth)
				displayedLogs[i] = padded + " " + ui.SubtleText.Render("│")
			} else {
				displayedLogs[i] = strings.Repeat(" ", logWidth) + " " + ui.SubtleText.Render("│")
			}
		}
	} else {
		maxOffset := totalLines - logCount
		if m.scrollOffset > maxOffset {
			m.scrollOffset = maxOffset
		}
		if m.scrollOffset < 0 {
			m.scrollOffset = 0
		}
		start := totalLines - logCount - m.scrollOffset
		end := start + logCount

		thumbStart := (start * logCount) / totalLines
		thumbEnd := (end * logCount) / totalLines
		if thumbEnd-thumbStart < 1 {
			thumbEnd = thumbStart + 1
		}
		if thumbEnd > logCount {
			thumbEnd = logCount
		}

		for i := 0; i < logCount; i++ {
			padded := ui.PadPlain(wrappedLogs[start+i], logWidth)
			sbChar := ui.SubtleText.Render("│")
			if i >= thumbStart && i < thumbEnd {
				sbChar = ui.OKText.Render("┃")
			}
			displayedLogs[i] = padded + " " + sbChar
		}
	}

	return strings.Join(displayedLogs, "\n")
}

func (m Model) sectionTitle(text string) string {
	return lipgloss.NewStyle().Foreground(ui.Accent).Bold(true).Render(text)
}

func (m Model) heroLines(width int, subtitle string) []string {
	title := m.statusLight() + " " + ui.Title.Render("Voice Input")
	if m.busy {
		title += " " + ui.OKText.Render("working…")
	}
	lines := []string{title}
	if subtitle != "" {
		lines = append(lines, ui.MutedText.Render(ui.TruncateStyled(subtitle, width)))
	}
	return lines
}

func (m Model) statusLight() string {
	style := lipgloss.NewStyle().Foreground(m.tone())
	return style.Render("●")
}

func (m Model) actionPrimary(label string, enabled bool, width int) string {
	style := lipgloss.NewStyle().Foreground(ui.Muted)
	prefix := "  "
	if enabled && !m.busy {
		style = lipgloss.NewStyle().Foreground(ui.Accent).Bold(true)
		prefix = "→ "
	}
	return style.Render(ui.TruncatePlain(prefix+label+" (enter)", width))
}

func (m Model) actionSecondary(key, label string, enabled bool) string {
	style := lipgloss.NewStyle().Foreground(ui.Muted)
	if enabled && !m.busy {
		style = lipgloss.NewStyle().Foreground(ui.Text)
	}
	return style.Render("  " + label + " (" + key + ")")
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

func (m Model) helpItems() []string {
	items := []string{
		ui.HelpItem("enter", m.primaryHelp()),
	}
	switch m.state() {
	case "nomodel":
		items = append(items, ui.HelpItem("d", "diagnose"))
	case "downloading":
		// cancel is enter
	case "recording":
		// stop is enter
	default:
		items = append(items,
			ui.HelpItem("e", "bindings"),
			ui.HelpItem("k", "key tester"),
			ui.HelpItem("d", "diagnose"),
			ui.HelpItem("t", "test tui"),
			ui.HelpItem("s", "setup"),
			ui.HelpItem("x", "delete model"),
		)
		if len(m.recentItems()) > 0 {
			items = append(items, ui.HelpItem("c", "clear recent"))
		}
	}
	items = append(items, ui.HelpItem("r", "refresh"), ui.HelpItem("q", "quit"))
	return items
}

func (m Model) kvLine(label, value string, width int) string {
	labelStyle := lipgloss.NewStyle().Foreground(ui.Text)
	valueStyle := lipgloss.NewStyle().Foreground(ui.Muted)
	left := labelStyle.Render(label)
	gap := 2
	remain := width - lipgloss.Width(label) - gap
	if remain < 8 {
		remain = 8
	}
	return left + strings.Repeat(" ", gap) + valueStyle.Render(ui.TruncatePlain(value, remain))
}

func boolReady(ok bool) string {
	if ok {
		return "ready"
	}
	return "missing"
}

func boolRunning(ok bool) string {
	if ok {
		return "running"
	}
	return "idle"
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

func (m Model) fetchLogs() tea.Cmd {
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-voice", "logs")
		return logsMsg{lines: result.Lines, err: result.Err}
	}
}

func (m Model) runAction(action string) tea.Cmd {
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-voice", action)
		return actionLogMsg{action: action, lines: result.Lines, err: result.Err}
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
		return "Test completed"
	case "diagnose":
		return "Diagnosis completed"
	case "delete-model":
		return "Model deleted successfully"
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
