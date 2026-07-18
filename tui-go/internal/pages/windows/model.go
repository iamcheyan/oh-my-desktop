package windows

import (
	"fmt"
	"os/exec"
	"strings"
	"time"

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

type logsMsg struct {
	lines []string
	err   error
}

type actionMsg struct {
	action string
	lines  []string
	err    error
}

type tickMsg time.Time

type Model struct {
	backend       backend.Backend
	status        status
	logs          []string
	width         int
	height        int
	busy          bool
	err           string
	scrollOffset  int
	confirmRemove bool
}

func New(b backend.Backend) Model {
	return Model{backend: b}
}

func (m Model) Init() tea.Cmd {
	return tea.Batch(m.fetchStatus(), m.fetchLogs(), tick())
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
		} else if msg.Type == tea.MouseWheelDown {
			m.scrollOffset--
			if m.scrollOffset < 0 {
				m.scrollOffset = 0
			}
			return m, nil
		}

		if msg.Action == tea.MouseActionPress && msg.Button == tea.MouseButtonLeft {
			x, y := msg.X, msg.Y

			width := m.width
			const (
				screenPaddingX = 2
				panelGap       = 2
			)
			contentW := width - screenPaddingX
			leftW := min(54, max(38, contentW/3))
			rightW := contentW - leftW - panelGap
			if rightW < 40 {
				leftW = max(28, contentW-panelGap-40)
			}

			leftInnerX := 1
			leftInnerY := 1

			// 1. Primary Action Button
			primaryW := len(m.primaryActionLabel()) + 12
			if y >= leftInnerY+9 && y <= leftInnerY+11 && x >= leftInnerX && x < leftInnerX+primaryW {
				if !m.busy {
					m.busy = true
					return m, m.runAction(m.primaryActionName())
				}
			}

			// 2. Refresh Button
			refreshStartX := leftInnerX + primaryW + 1
			if y >= leftInnerY+9 && y <= leftInnerY+11 && x >= refreshStartX && x < refreshStartX+12 {
				return m, tea.Batch(m.fetchStatus(), m.fetchLogs())
			}

			// 3. Web Button
			if y >= leftInnerY+13 && y <= leftInnerY+15 && x >= leftInnerX && x < leftInnerX+17 {
				if !m.busy {
					m.busy = true
					return m, m.runAction("web")
				}
			}

			// 4. Start Button
			if y >= leftInnerY+13 && y <= leftInnerY+15 && x >= leftInnerX+18 && x < leftInnerX+30 {
				if !m.running() && !m.busy {
					m.busy = true
					return m, m.runAction("start")
				}
			}

			// 5. Stop Button
			if y >= leftInnerY+16 && y <= leftInnerY+18 && x >= leftInnerX && x < leftInnerX+12 {
				if m.running() && !m.busy {
					m.busy = true
					return m, m.runAction("stop")
				}
			}
		}
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			m.scrollOffset++
		case "down", "j":
			m.scrollOffset--
			if m.scrollOffset < 0 {
				m.scrollOffset = 0
			}
		case "pgup":
			m.scrollOffset += 10
		case "pgdown":
			m.scrollOffset -= 10
			if m.scrollOffset < 0 {
				m.scrollOffset = 0
			}
		case "home":
			m.scrollOffset = 999999
		case "end":
			m.scrollOffset = 0
		case "q", "ctrl+c":
			return m, tea.Quit
		case "esc":
			if m.confirmRemove {
				m.confirmRemove = false
				return m, nil
			}
			return m, tea.Quit
		case "enter":
			if !m.busy {
				m.busy = true
				return m, m.runAction(m.primaryActionName())
			}
		case "d":
			if m.configured() && !m.busy {
				m.confirmRemove = true
			}
		case "y":
			if m.confirmRemove && !m.busy {
				m.confirmRemove = false
				m.busy = true
				return m, m.runAction("remove --yes")
			}
		case "n":
			if m.confirmRemove {
				m.confirmRemove = false
			}
		case "r":
			return m, tea.Batch(m.fetchStatus(), m.fetchLogs())
		case "c":
			if m.ready() && !m.busy {
				m.busy = true
				return m, m.runAction("connect")
			}
		case "s":
			if !m.running() && !m.busy {
				m.busy = true
				return m, m.runAction("start")
			}
		case "x":
			if m.running() && !m.busy {
				m.busy = true
				return m, m.runAction("stop")
			}
		case "w":
			if !m.busy {
				m.busy = true
				return m, m.runAction("web")
			}
		}
	case statusMsg:
		if msg.err != nil {
			m.err = msg.err.Error()
		} else {
			m.status = msg.values
			m.err = ""
		}
	case logsMsg:
		if msg.err == nil {
			m.logs = msg.lines
		}
	case actionMsg:
		m.busy = false
		if msg.err != nil {
			m.err = msg.err.Error()
		}
		m.logs = append(m.logs, append([]string{"$ " + msg.action}, msg.lines...)...)
		m.logs = ui.ClipLines(m.logs, 140)
		return m, tea.Batch(m.fetchStatus(), m.fetchLogs())
	case tickMsg:
		return m, tea.Batch(m.fetchStatus(), m.fetchLogs(), tick())
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
		screenPaddingX = 2 // Screen.Padding(_, 1) on each side
		screenPaddingY = 2 // Screen.Padding(1, _) on each side
		panelGap       = 2 // "  " between panels
		fixedRows      = 1 // footer help
	)

	contentW := width - screenPaddingX
	if contentW < 40 {
		contentW = 40
	}
	contentH := height - screenPaddingY - fixedRows
	if contentH < 8 {
		contentH = 8
	}

	leftW := min(54, max(38, contentW/3))
	rightW := contentW - leftW - panelGap
	if rightW < 40 {
		rightW = 40
		leftW = max(28, contentW-panelGap-rightW)
	}

	left := ui.PreserveBackground(ui.FitBlock(m.controlView(leftW), leftW, contentH), ui.Background)
	right := ui.PreserveBackground(ui.FitBlock(m.logView(rightW, contentH), rightW, contentH), ui.Background)

	var helpText string
	if m.confirmRemove {
		helpText = ui.HelpText(ui.HelpItem("y", "confirm remove"), ui.HelpItem("n/esc", "cancel"))
	} else {
		helpText = ui.HelpText(
			ui.HelpItem("enter", m.primaryActionLabel()),
			ui.HelpItem("c", "connect"),
			ui.HelpItem("s", "start"),
			ui.HelpItem("x", "stop"),
			ui.HelpItem("w", "web"),
			ui.HelpItem("d", "remove"),
			ui.HelpItem("r", "refresh"),
			ui.HelpItem("q", "quit"),
		)
	}
	help := helpText

	return ui.Screen.Padding(1, 1).Render(
		lipgloss.JoinVertical(lipgloss.Left,
			lipgloss.JoinHorizontal(lipgloss.Top, left, "  ", right),
			help,
		),
	)
}

func (m Model) controlView(width int) string {
	if m.status == nil {
		return "Loading..."
	}

	health := m.value("phase", "unknown")
	if m.ready() {
		health = "Ready"
	}

	title := ui.Title.Render("Windows VM")
	if m.busy {
		title += " " + ui.OKText.Render("working...")
	}
	if m.err != "" {
		title += " " + ui.DangerText.Render(m.err)
	}

	lines := []string{
		title,
		ui.MutedText.Render(ui.TruncateStyled(fmt.Sprintf("%s · RDP %s · Web %s", health, m.value("rdpEndpoint", "-"), upDownPlain(m.bool("webReachable"))), width)),
		"",
		lipgloss.JoinHorizontal(lipgloss.Top,
			ui.StatusPill("Docker", m.bool("dockerAccess")),
			ui.StatusPill("KVM", m.bool("kvm")),
			ui.StatusPill("RDP", m.bool("rdpReachable")),
		),
		"",
		ui.Section.Render("Actions"),
		ui.MutedText.Render(ui.TruncateStyled(m.primaryText(), width)),
		"",
		m.actionButtons(),
		"",
		m.opsButtons(),
		"",
	}

	if m.hasSystemBlocker() {
		lines = append(lines,
			ui.Section.Render("Requirements Blocked"),
			ui.Row("KVM Virtualization", ui.BoolStatus(m.bool("kvm")), width),
			ui.Row("Docker Daemon", ui.BoolStatus(m.bool("dockerAccess")), width),
			ui.Row("Docker Compose", ui.BoolStatus(m.bool("compose")), width),
			ui.Row("Free RDP Client", ui.BoolStatus(m.bool("freerdp")), width),
			ui.Row("Free disk space", ui.BoolStatus(m.diskAvailable() >= 74), width),
			"",
		)
	}

	lines = append(lines,
		ui.Section.Render("Connection"),
		ui.Row("Web", m.value("web", "-")+"  "+ui.BoolStatus(m.bool("webReachable")), width),
		ui.Row("RDP", m.value("rdpEndpoint", "-")+"  "+ui.BoolStatus(m.bool("rdpReachable")), width),
		"",
		ui.Section.Render("Runtime"),
		ui.Row("Container", m.value("container", "-"), width),
		ui.Row("Docker", ui.BoolStatus(m.bool("dockerAccess")), width),
		ui.Row("KVM", ui.BoolStatus(m.bool("kvm")), width),
		"",
		ui.Section.Render("Specs"),
		ui.Row("RAM", m.value("ram", "-"), width),
		ui.Row("CPU", m.value("cpu", "-"), width),
		ui.Row("Disk", m.value("disk", "-"), width),
		ui.Row("User", m.value("user", "-"), width),
		ui.Row("Shared", m.value("sharedDir", "-"), width),
	)

	if m.confirmRemove {
		lines = append(lines,
			"",
			ui.Section.Render("Danger Zone"),
			ui.DangerText.Render("Press y to CONFIRM REMOVE | n to cancel"),
			ui.DangerText.Render("Deletes container & local VM storage."),
		)
	} else {
		if m.configured() {
			lines = append(lines,
				"",
				ui.Section.Render("Danger Zone"),
				ui.SubtleText.Render("d Remove VM (deletes container & storage)"),
			)
		}
	}

	return strings.Join(lines, "\n")
}

func (m Model) logView(width, height int) string {
	if m.status == nil {
		return "Loading..."
	}

	lines := []string{
		ui.Title.Render("Logs"),
		ui.MutedText.Render(ui.TruncateStyled(fmt.Sprintf("Container %s · %s", m.value("container", "-"), m.value("phase", "-")), width)),
		"",
	}

	// Expand elements with internal newlines to count actual rendered lines
	var staticLines []string
	for _, l := range lines {
		staticLines = append(staticLines, strings.Split(l, "\n")...)
	}

	logCount := height - len(staticLines)
	if logCount < 0 {
		if height >= 0 && len(staticLines) > height {
			staticLines = staticLines[:height]
		}
		return strings.Join(staticLines, "\n")
	}
	if logCount == 0 {
		return strings.Join(staticLines, "\n")
	}

	// Wrap log lines to fit within (width - 2) to leave 2 columns for space + scrollbar
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
		// No logs to show, pad with blank lines
		for i := 0; i < logCount; i++ {
			displayedLogs[i] = strings.Repeat(" ", logWidth) + "  "
		}
	} else if totalLines <= logCount {
		// All logs fit, draw solid scrollbar for log rows, trailing blank rows have track
		for i := 0; i < logCount; i++ {
			if i < totalLines {
				padded := ui.PadPlain(wrappedLogs[i], logWidth)
				displayedLogs[i] = padded + " " + ui.OKText.Render("┃")
			} else {
				displayedLogs[i] = strings.Repeat(" ", logWidth) + " " + ui.SubtleText.Render("│")
			}
		}
	} else {
		// Logs overflow, clamp scrollOffset and slide viewport
		maxOffset := totalLines - logCount
		scrollOffset := m.scrollOffset
		if scrollOffset > maxOffset {
			scrollOffset = maxOffset
		}
		if scrollOffset < 0 {
			scrollOffset = 0
		}

		start := totalLines - logCount - scrollOffset
		end := totalLines - scrollOffset

		// Calculate scrollbar thumb position
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

	for _, dLine := range displayedLogs {
		staticLines = append(staticLines, dLine)
	}

	return strings.Join(staticLines, "\n")
}

func (m Model) actionButtons() string {
	var primaryBtn string
	label := m.primaryActionLabel()

	enabled := !m.busy
	if m.primaryActionName() == "connect" {
		enabled = enabled && m.bool("freerdp")
	}

	if enabled {
		primaryBtn = ui.PrimaryButtonView(ui.ActionText("enter", label))
	} else {
		primaryBtn = ui.DisabledButtonView(ui.ActionText("enter", label))
	}

	refreshBtn := ui.ButtonView(ui.ActionText("r", "Refresh"), false)
	if m.busy {
		refreshBtn = ui.DisabledButtonView(ui.ActionText("r", "Refresh"))
	}

	return lipgloss.JoinHorizontal(lipgloss.Top, primaryBtn, refreshBtn)
}

func (m Model) opsButtons() string {
	start := ui.ButtonView(ui.ActionText("s", "Start"), false)
	stop := ui.ButtonView(ui.ActionText("x", "Stop"), false)
	web := ui.ButtonView(ui.ActionText("w", "Open console"), false)
	if m.running() || m.busy {
		start = ui.DisabledButtonView(ui.ActionText("s", "Start"))
	}
	if !m.running() || m.busy {
		stop = ui.DisabledButtonView(ui.ActionText("x", "Stop"))
	}
	if m.busy {
		web = ui.DisabledButtonView(ui.ActionText("w", "Open console"))
	}
	return lipgloss.JoinVertical(lipgloss.Left,
		lipgloss.JoinHorizontal(lipgloss.Top, web, start),
		stop,
	)
}

func (m Model) fetchStatus() tea.Cmd {
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-windows-vm", "status")
		if result.Err != nil {
			return statusMsg{err: result.Err}
		}
		return statusMsg{values: backend.ParseKV(result.Lines)}
	}
}

func (m Model) fetchLogs() tea.Cmd {
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-windows-vm", "logs")
		return logsMsg{lines: result.Lines, err: result.Err}
	}
}

func (m Model) runAction(action string) tea.Cmd {
	return func() tea.Msg {
		if action == "connect" || action == "launch" {
			// Run GUI app detached
			cmd := exec.Command(m.backend.Bin("omd-settings-windows-vm"), action)
			cmd.Dir = m.backend.Root
			err := cmd.Start()
			var lines []string
			if err != nil {
				return actionMsg{action: action, err: err}
			}
			return actionMsg{action: action, lines: lines}
		}

		result := m.backend.Run("omd-settings-windows-vm", action)
		return actionMsg{action: action, lines: result.Lines, err: result.Err}
	}
}

func tick() tea.Cmd {
	return tea.Tick(3*time.Second, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

func (m Model) diskAvailable() int {
	var val int
	fmt.Sscanf(m.value("diskAvailable", "0"), "%d", &val)
	return val
}

func (m Model) storageUsedBytes() int {
	var val int
	fmt.Sscanf(m.value("storageUsedBytes", "0"), "%d", &val)
	return val
}

func (m Model) hasSystemBlocker() bool {
	return !m.bool("kvm") || !m.bool("dockerCli") || !m.bool("dockerAccess") || !m.bool("compose") || m.diskAvailable() < 74
}

func (m Model) configured() bool {
	return m.bool("configured")
}

func (m Model) partial() bool {
	return m.configured() && m.value("container", "missing") == "missing" && m.storageUsedBytes() <= 1048576
}

func (m Model) stopped() bool {
	return m.configured() && m.value("container", "missing") != "missing" && !m.running()
}

func (m Model) primaryActionLabel() string {
	if m.busy {
		return "Working..."
	}
	if m.hasSystemBlocker() {
		return "Fix requirements"
	}
	if !m.configured() || m.partial() {
		return "Install Windows"
	}
	if m.ready() {
		return "Connect"
	}
	if m.running() && !m.ready() {
		return "Open console"
	}
	if m.stopped() {
		return "Start & connect"
	}
	return "Repair / start"
}

func (m Model) primaryActionName() string {
	if m.hasSystemBlocker() {
		return "auto-fix"
	}
	if !m.configured() || m.partial() {
		return "install-defaults"
	}
	if m.ready() {
		return "connect"
	}
	if m.running() && !m.ready() {
		return "web"
	}
	if m.stopped() {
		return "launch"
	}
	return "install-defaults"
}

func (m Model) primaryText() string {
	if m.hasSystemBlocker() {
		return "Resolve host requirements before install or start."
	}
	if !m.configured() || m.partial() {
		return "Installs Dockurr Windows 11 with sensible defaults (can take a while)."
	}
	if m.ready() {
		return "Open a FreeRDP session to the running VM."
	}
	if m.running() && !m.ready() {
		return "Windows is still setting up — use the web console to watch progress."
	}
	if m.stopped() {
		return "Start the container and connect over RDP."
	}
	return "Repair or start the VM stack."
}

func (m Model) value(key, fallback string) string {
	if m.status == nil {
		return fallback
	}
	if value := m.status[key]; value != "" {
		return value
	}
	return fallback
}

func (m Model) bool(key string) bool {
	return m.value(key, "false") == "true"
}

func upDownPlain(ok bool) string {
	if ok {
		return "up"
	}
	return "down"
}

func (m Model) ready() bool {
	return m.bool("ready") || (m.bool("rdpReachable") && m.bool("webReachable"))
}

func (m Model) running() bool {
	return m.value("container", "") == "running"
}
