package windows

import (
	"fmt"
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
	backend      backend.Backend
	status       status
	logs         []string
	width        int
	height       int
	busy         bool
	err          string
	scrollOffset int
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
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "esc", "ctrl+c":
			return m, tea.Quit
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
		screenPaddingX = 4 // Screen.Padding(_, 2) on each side
		screenPaddingY = 2 // Screen.Padding(1, _) on each side
		panelGap       = 2 // "  " between panels
		panelBorderW   = 2 // left+right border
		panelBorderH   = 2 // top+bottom border
		panelPadW      = 4 // Padding(_, 2) on each side
		panelPadH      = 2 // Padding(1, _) on each side
		fixedRows      = 2 // header + footer help
	)

	// lipgloss Style.Width/Height set the inner box (content + padding) and
	// do NOT include the border. So a panel's total footprint is:
	//   Width = innerW + borderW,  Height = innerH + borderH
	// and the pure content area is innerW - padW, innerH - padH.
	panelInnerW := (width - screenPaddingX - panelGap - panelBorderW*2 - panelPadW*2) / 2
	if panelInnerW < 20 {
		panelInnerW = 20
	}
	panelInnerH := height - screenPaddingY - fixedRows - panelBorderH - panelPadH
	if panelInnerH < 8 {
		panelInnerH = 8
	}
	// Style.Width/Height take the inner box (content + padding).
	panelBoxW := panelInnerW + panelPadW
	panelBoxH := panelInnerH + panelPadH

	header := ui.Title.Render("Windows VM") + " " + ui.MutedText.Render("Go settings TUI")
	if m.busy {
		header += " " + ui.OKText.Render("working...")
	}
	if m.err != "" {
		header += " " + ui.DangerText.Render(m.err)
	}

	left := ui.PanelBox.Width(panelBoxW).Height(panelBoxH).Render(
		ui.PreserveBackground(ui.FitBlock(m.statusView(panelInnerW), panelInnerW, panelInnerH), ui.Panel),
	)
	right := ui.PanelBox.Width(panelBoxW).Height(panelBoxH).Render(
		ui.PreserveBackground(ui.FitBlock(m.opsView(panelInnerW, panelInnerH), panelInnerW, panelInnerH), ui.Panel),
	)
	help := ui.SubtleText.Render("r refresh  c connect  s start  x stop  w web console  q quit")

	return ui.Screen.Padding(1, 2).Render(
		lipgloss.JoinVertical(lipgloss.Left,
			header,
			lipgloss.JoinHorizontal(lipgloss.Top, left, "  ", right),
			help,
		),
	)
}

func (m Model) statusView(width int) string {
	if m.status == nil {
		return "Loading..."
	}

	health := m.value("phase", "unknown")
	if m.ready() {
		health = "Ready"
	}

	return strings.Join([]string{
		ui.Title.Render("Windows VM"),
		ui.TruncateStyled(fmt.Sprintf("%s · RDP %s · web %s", health, m.value("rdpEndpoint", "-"), upDownPlain(m.bool("webReachable"))), width),
		"",
		ui.Section.Render("Primary action"),
		ui.MutedText.Render(ui.TruncateStyled(primaryText(m.status), width)),
		"",
		m.actionButtons(),
		"",
		ui.Section.Render("Runtime"),
		ui.Row("Container", m.value("container", "-"), width),
		ui.Row("Docker", ui.BoolStatus(m.bool("dockerAccess")), width),
		ui.Row("KVM", ui.BoolStatus(m.bool("kvm")), width),
	}, "\n")
}

func (m Model) opsView(width, height int) string {
	if m.status == nil {
		return "Loading..."
	}

	lines := []string{
		ui.Title.Render("Connection & Ops"),
		ui.TruncateStyled(fmt.Sprintf("Container %s · %s", m.value("container", "-"), m.value("phase", "-")), width),
		"",
		ui.Section.Render("Connection"),
		ui.Row("Web console", m.value("web", "-")+"  "+ui.BoolStatus(m.bool("webReachable")), width),
		ui.Row("RDP endpoint", m.value("rdpEndpoint", "-")+"  "+ui.BoolStatus(m.bool("rdpReachable")), width),
		"",
		m.opsButtons(),
		"",
		ui.Section.Render("Specs"),
		ui.Row("RAM", m.value("ram", "-"), width),
		ui.Row("CPU", m.value("cpu", "-"), width),
		ui.Row("Disk", m.value("disk", "-"), width),
		ui.Row("User", m.value("user", "-"), width),
		ui.Row("Shared", m.value("sharedDir", "-"), width),
		"",
		ui.Section.Render("Logs"),
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
	connect := ui.PrimaryButton.Render("c Connect")
	if !m.ready() || m.busy {
		connect = ui.DisabledButton.Render("c Connect")
	}
	refresh := ui.Button.Render("r Refresh")
	if m.busy {
		refresh = ui.DisabledButton.Render("r Refresh")
	}
	return lipgloss.JoinHorizontal(lipgloss.Top, connect, refresh)
}

func (m Model) opsButtons() string {
	start := ui.Button.Render("s Start")
	stop := ui.Button.Render("x Stop")
	web := ui.Button.Render("w Open console")
	if m.running() || m.busy {
		start = ui.DisabledButton.Render("s Start")
	}
	if !m.running() || m.busy {
		stop = ui.DisabledButton.Render("x Stop")
	}
	if m.busy {
		web = ui.DisabledButton.Render("w Open console")
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
		result := m.backend.Run("omd-settings-windows-vm", action)
		return actionMsg{action: action, lines: result.Lines, err: result.Err}
	}
}

func tick() tea.Cmd {
	return tea.Tick(3*time.Second, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
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

func primaryText(values status) string {
	if values["ready"] == "true" {
		return "Open a FreeRDP session to the running VM."
	}
	if values["container"] == "running" {
		return "Windows is still booting or installing. Refresh for progress."
	}
	return "Start the Windows VM container."
}
