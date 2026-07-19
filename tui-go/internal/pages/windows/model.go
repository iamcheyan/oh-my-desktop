package windows

import (
	"fmt"
	"math"
	"os/exec"
	"regexp"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"github.com/iamcheyan/oh-my-desktop/tui-go/internal/backend"
	"github.com/iamcheyan/oh-my-desktop/tui-go/internal/ui"
)

type logsMsg struct {
	lines []string
	err   error
}

// actionLogMsg is like backend.ActionMsg but carries the command's stdout so
// the log view can append "$ <action>" + output lines.
type actionLogMsg struct {
	action string
	lines  []string
	err    error
}

type tickMsg time.Time

type Model struct {
	backend       backend.Backend
	status        backend.Status
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
						{"Start only", "s"},
						{"Open web console", "w"},
						{"Stop VM", "x"},
						{"Remove VM", "d"},
						{"Confirm remove", "y"},
						{"Cancel", "n"},
						{"Install Windows", "enter"},
						{"Fix requirements", "enter"},
						{"Connect", "enter"},
						{"Start", "enter"},
						{"Open console", "enter"},
						{"Repair / start", "enter"},
					}
					for _, b := range buttons {
						idx := strings.Index(plain, b.text)
						if idx >= 0 {
							if msg.X >= idx-2 && msg.X <= idx+len(b.text)+2 {
								var keyMsg tea.KeyMsg
								if b.key == "enter" {
									keyMsg = tea.KeyMsg{Type: tea.KeyEnter}
								} else {
									keyMsg = tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune(b.key)}
								}
								return m.Update(keyMsg)
							}
						}
					}
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
			m.scrollOffset = math.MaxInt32
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
			if !m.busy && m.primaryActionName() != "" {
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
			if m.stopped() && !m.busy {
				m.busy = true
				return m, m.runAction("start")
			}
		case "x":
			if m.running() && !m.busy {
				m.busy = true
				return m, m.runAction("stop")
			}
		case "w":
			if m.running() && !m.busy {
				m.busy = true
				return m, m.runAction("web")
			}
		}
	case backend.StatusMsg:
		if msg.Err != nil {
			m.err = msg.Err.Error()
		} else {
			m.status = msg.Values
			m.err = ""
		}
	case logsMsg:
		if msg.err == nil {
			m.logs = msg.lines
		}
	case actionLogMsg:
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
	help := m.helpItems()
	if m.confirmRemove {
		help = []string{
			ui.HelpItem("y", "confirm remove"),
			ui.HelpItem("n/esc", "cancel"),
		}
	}

	showRight := m.showSidePanel()
	return ui.RenderPage(ui.Page{
		Width:  m.width,
		Height: m.height,
		Hero:   m.pageHero(),
		Left:   m.mainPanel(),
		Right:  m.sidePanelBody(),
		Wide:   showRight,
		Help:   help,
	})
}

func (m Model) pageHero() string {
	subtitle := m.heroSubtitle()
	msg := ""
	if m.err != "" {
		msg = ui.TruncatePlain(m.err, 48)
	}
	return ui.Hero("Windows VM", subtitle, ui.HeroOpts{
		Tone:    m.heroTone(),
		Busy:    m.busy,
		Message: msg,
	})
}

func (m Model) heroTone() ui.Tone {
	switch m.primaryState() {
	case "ready":
		return ui.ToneOK
	case "booting", "install":
		return ui.ToneWarn
	case "blocked", "repair":
		return ui.ToneDanger
	case "stopped":
		return ui.ToneIdle
	default:
		if m.busy {
			return ui.ToneWarn
		}
		return ui.ToneIdle
	}
}

func (m Model) heroSubtitle() string {
	if m.status == nil {
		return "Loading…"
	}
	if m.confirmRemove {
		return "Confirm destructive action."
	}
	switch m.primaryState() {
	case "blocked":
		return "Host requirements need attention before install."
	case "install":
		return "Windows is not installed on this machine yet."
	case "booting":
		phase := m.value("phase", "starting")
		progress := m.value("progressPercent", "")
		if progress != "" {
			return fmt.Sprintf("%s · %s%%", phase, progress)
		}
		if phase != "" {
			return phase
		}
		return "Windows is starting up…"
	case "ready":
		return "Ready · RDP and web console are reachable."
	case "stopped":
		return "VM is installed but not running."
	default:
		return "VM stack looks partial or broken."
	}
}

// showSidePanel is true once there is something worth showing on the right:
// live logs during work/boot, or connection details after the VM exists.
func (m Model) showSidePanel() bool {
	if m.status == nil {
		return false
	}
	if m.confirmRemove {
		return false
	}
	state := m.primaryState()
	switch state {
	case "blocked", "install":
		// Still show logs while a fix/install action is running.
		return m.busy
	case "booting", "ready", "stopped", "repair":
		return true
	default:
		return m.busy
	}
}

func (m Model) mainPanel() string {
	if m.status == nil {
		return "Loading…"
	}
	if m.confirmRemove {
		return m.confirmRemoveView()
	}
	switch m.primaryState() {
	case "blocked":
		return m.blockedView()
	case "install":
		return m.installView()
	case "booting":
		return m.bootingView()
	case "ready":
		return m.readyView()
	case "stopped":
		return m.stoppedView()
	default:
		return m.repairView()
	}
}

func (m Model) actionPrimary() string {
	label := m.primaryActionLabel()
	enabled := !m.busy && m.primaryActionName() != ""
	if m.primaryActionName() == "connect" {
		enabled = enabled && m.bool("freerdp")
	}
	return ui.PrimaryLine(label, "enter", enabled)
}

func (m Model) actionSecondary(key, label string, enabled bool) string {
	if key == "d" {
		return ui.DangerActionLine(key, label, enabled && !m.busy)
	}
	return ui.ActionLine(key, label, enabled && !m.busy)
}

// blockedView: host cannot install/run yet — only show failures + fix CTA.
func (m Model) blockedView() string {
	lines := []string{
		ui.SectionTitle("What's Blocking"),
		ui.MutedText.Render("Only failed checks are listed. Fix these, then install."),
		"",
	}
	for _, row := range m.blockerDetails(48) {
		lines = append(lines, row)
	}
	lines = append(lines, "",
		ui.SectionTitle("Next Step"),
		ui.MutedText.Render(m.primaryText()),
		m.actionPrimary(),
		m.actionSecondary("r", "Refresh status", true),
	)
	return strings.Join(lines, "\n")
}

// installView: ready to install — guide the user, hide manage/connect/logs.
func (m Model) installView() string {
	lines := []string{
		ui.SectionTitle("Get Started"),
		ui.MutedText.Render("Installs a Dockurr Windows 11 VM with sensible defaults."),
		ui.MutedText.Render("First run downloads an image and can take a while."),
		"",
		ui.SectionTitle("Defaults"),
		ui.KVLine("Shared folder", m.value("sharedDir", "~/Windows"), 48),
		ui.KVLine("Web console", m.value("web", "http://127.0.0.1:8006"), 48),
		ui.KVLine("RDP", m.value("rdpEndpoint", "127.0.0.1:3389"), 48),
		ui.KVLine("Host free disk", fmt.Sprintf("%d GB available", m.diskAvailable()), 48),
		"",
		ui.SectionTitle("Next Step"),
		ui.MutedText.Render(m.primaryText()),
		m.actionPrimary(),
		m.actionSecondary("r", "Refresh status", true),
	}
	return strings.Join(lines, "\n")
}

func (m Model) bootingView() string {
	lines := []string{
		ui.SectionTitle("While You Wait"),
		ui.MutedText.Render("Use the web console to watch install/boot progress."),
		"",
		ui.SectionTitle("Actions"),
		m.actionPrimary(),
	}
	if m.running() {
		lines = append(lines, m.actionSecondary("w", "Open web console", true))
		lines = append(lines, m.actionSecondary("x", "Stop VM", true))
	}
	lines = append(lines, m.actionSecondary("r", "Refresh status", true))
	return strings.Join(lines, "\n")
}

func (m Model) readyView() string {
	lines := []string{
		ui.SectionTitle("Connection"),
		ui.KVLine("RDP", m.value("rdpEndpoint", "-"), 48),
		ui.KVLine("Web", m.value("web", "-"), 48),
		"",
		ui.SectionTitle("Actions"),
		m.actionPrimary(),
		m.actionSecondary("w", "Open web console", true),
		m.actionSecondary("x", "Stop VM", true),
		m.actionSecondary("r", "Refresh status", true),
		"",
		ui.SectionTitle("Danger"),
		m.actionSecondary("d", "Remove VM", true),
		ui.SubtleText.Render("Deletes container and local VM storage."),
	}
	return strings.Join(lines, "\n")
}

func (m Model) stoppedView() string {
	lines := []string{
		ui.SectionTitle("Specs"),
		ui.KVLine("RAM", nonEmpty(m.value("ram", ""), "-"), 48),
		ui.KVLine("CPU", nonEmpty(m.value("cpu", ""), "-"), 48),
		ui.KVLine("Disk", nonEmpty(m.value("disk", ""), "-"), 48),
		ui.KVLine("User", nonEmpty(m.value("user", ""), "-"), 48),
		ui.KVLine("Shared", m.value("sharedDir", "-"), 48),
		"",
		ui.SectionTitle("Actions"),
		m.actionPrimary(),
		m.actionSecondary("s", "Start only (no RDP)", true),
		m.actionSecondary("r", "Refresh status", true),
		"",
		ui.SectionTitle("Danger"),
		m.actionSecondary("d", "Remove VM", true),
		ui.SubtleText.Render("Deletes container and local VM storage."),
	}
	return strings.Join(lines, "\n")
}

func (m Model) repairView() string {
	lines := []string{
		ui.SectionTitle("Status"),
		ui.KVLine("Phase", m.value("phase", "-"), 48),
		ui.KVLine("Container", m.value("container", "-"), 48),
		ui.KVLine("Docker", boolLabel(m.bool("dockerAccess")), 48),
		ui.KVLine("KVM", boolLabel(m.bool("kvm")), 48),
		"",
		ui.SectionTitle("Actions"),
		m.actionPrimary(),
		m.actionSecondary("r", "Refresh status", true),
	}
	if m.configured() {
		lines = append(lines, "",
			ui.SectionTitle("Danger"),
			m.actionSecondary("d", "Remove VM", true),
			ui.SubtleText.Render("Deletes container and local VM storage."),
		)
	}
	return strings.Join(lines, "\n")
}

func (m Model) confirmRemoveView() string {
	lines := []string{
		ui.SectionTitle("Remove Windows VM"),
		ui.DangerText.Render("This deletes the container and local VM storage."),
		ui.DangerText.Render(m.value("storageDir", "~/.windows")),
		"",
		ui.DangerText.Render("→ Confirm remove (y)"),
		lipgloss.NewStyle().Foreground(ui.Text).Render("Cancel (n / esc)"),
	}
	return strings.Join(lines, "\n")
}

// sidePanelBody is the right column content; height is applied by RenderPage.
func (m Model) sidePanelBody() string {
	if !m.showSidePanel() {
		return ""
	}
	state := m.primaryState()
	// Booting / busy / repair: logs are the useful right pane.
	if m.busy || state == "booting" || state == "repair" || m.isInstallingPhase() {
		return m.logViewBody()
	}
	// Ready / stopped: connection summary + optional short logs.
	lines := []string{
		ui.SectionTitle("Details"),
		ui.MutedText.Render(fmt.Sprintf("%s · %s", m.vmStateLabel(), m.value("phase", "-"))),
		"",
		ui.SectionTitle("Connection"),
		ui.KVLine("Web", fmt.Sprintf("%s  %s", m.value("web", "-"), boolLabel(m.bool("webReachable"))), 48),
		ui.KVLine("RDP", fmt.Sprintf("%s  %s", m.value("rdpEndpoint", "-"), boolLabel(m.bool("rdpReachable"))), 48),
		ui.KVLine("Container", m.value("container", "-"), 48),
		"",
		ui.SectionTitle("Logs"),
		m.logBody(48, 12),
	}
	return strings.Join(lines, "\n")
}

func (m Model) logViewBody() string {
	lines := []string{
		ui.SectionTitle("Logs"),
		m.logBody(48, 18),
	}
	return strings.Join(lines, "\n")
}

func (m Model) isInstallingPhase() bool {
	phase := strings.ToLower(m.value("phase", ""))
	return strings.Contains(phase, "install") ||
		strings.Contains(phase, "pull") ||
		strings.Contains(phase, "download") ||
		strings.Contains(phase, "extract")
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
				displayedLogs[i] = padded + " " + ui.OKText.Render("┃")
			} else {
				displayedLogs[i] = strings.Repeat(" ", logWidth) + " " + ui.SubtleText.Render("│")
			}
		}
	} else {
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

type reqCheck struct {
	ok     bool
	label  string
	detail string
}

func (m Model) allRequirementChecks() []reqCheck {
	diskOK := m.diskAvailable() >= 74
	diskDetail := fmt.Sprintf("%d GB free (need ≥ 74 GB)", m.diskAvailable())
	if diskOK {
		diskDetail = fmt.Sprintf("%d GB free", m.diskAvailable())
	}

	dockerDetail := "Docker daemon reachable"
	if !m.bool("dockerAccess") {
		if err := m.value("dockerError", ""); err != "" {
			dockerDetail = err
		} else if !m.bool("dockerDaemon") {
			dockerDetail = "Docker daemon is not running"
		} else if !m.bool("dockerGroupMember") {
			dockerDetail = "User is not in the docker group (re-login after usermod)"
		} else {
			dockerDetail = "Cannot access Docker socket"
		}
	}

	return []reqCheck{
		{m.bool("kvm"), "KVM virtualization", "Hardware virtualization (/dev/kvm)"},
		{m.bool("dockerCli"), "Docker CLI", "docker command available"},
		{m.bool("dockerAccess"), "Docker access", dockerDetail},
		{m.bool("compose"), "Docker Compose", "compose plugin or docker-compose"},
		{m.bool("freerdp"), "FreeRDP client", nonEmpty(m.value("freerdpBin", ""), "xfreerdp not found")},
		{diskOK, "Free disk space", diskDetail},
	}
}

func (m Model) blockerDetails(width int) []string {
	var lines []string
	for _, c := range m.allRequirementChecks() {
		if c.ok {
			continue
		}
		mark := lipgloss.NewStyle().Foreground(ui.Danger).Render("✗")
		label := lipgloss.NewStyle().Foreground(ui.Text).Bold(true).Render(" " + c.label)
		lines = append(lines, mark+label)
		if c.detail != "" {
			lines = append(lines, ui.MutedText.Render("  "+ui.TruncatePlain(c.detail, max(8, width-2))))
		}
	}
	if len(lines) == 0 {
		lines = append(lines, ui.OKText.Render("✓ All host checks passed"))
	}
	return lines
}

func nonEmpty(v, fallback string) string {
	if strings.TrimSpace(v) == "" {
		return fallback
	}
	return v
}

func boolLabel(ok bool) string {
	if ok {
		return "ok"
	}
	return "no"
}

func (m Model) fetchStatus() tea.Cmd {
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-windows-vm", "status")
		if result.Err != nil {
			return backend.StatusMsg{Err: result.Err}
		}
		return backend.StatusMsg{Values: backend.ParseStatus(result.Lines)}
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
			cmd := exec.Command("setsid", m.backend.Bin("omd-settings-windows-vm"), action)
			cmd.Dir = m.backend.Root
			err := cmd.Start()
			if err != nil {
				return actionLogMsg{action: action, err: err}
			}
			return actionLogMsg{action: action}
		}

		result := m.backend.Run("omd-settings-windows-vm", action)
		return actionLogMsg{action: action, lines: result.Lines, err: result.Err}
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

// primaryMeta holds the label, action name, and descriptive text for one VM
// phase. primaryState() picks the row; primary() returns the full tuple so
// callers do not re-evaluate the same predicates three times.
type primaryMeta struct {
	label string
	name  string
	text  string
}

var primaryTable = map[string]primaryMeta{
	"blocked": {"Fix requirements", "auto-fix", "Resolve host requirements before install or start."},
	"install": {"Install Windows", "install-defaults", "Installs Dockurr Windows 11 with sensible defaults (can take a while)."},
	"ready":   {"Connect", "connect", "Open a FreeRDP session to the running VM."},
	"booting": {"Open console", "web", "Windows is still setting up — use the web console to watch progress."},
	"stopped": {"Start", "launch", "Start the Windows VM and open RDP when ready."},
	"repair":  {"Repair / start", "install-defaults", "Repair or start the VM stack."},
}

// primaryState returns the key into primaryTable for the current VM phase.
func (m Model) primaryState() string {
	if m.hasSystemBlocker() {
		return "blocked"
	}
	if !m.configured() || m.partial() {
		return "install"
	}
	if m.ready() {
		return "ready"
	}
	if m.running() && !m.ready() {
		return "booting"
	}
	if m.stopped() {
		return "stopped"
	}
	return "repair"
}

func (m Model) primary() primaryMeta {
	if m.busy {
		return primaryMeta{label: "Working...", name: "", text: ""}
	}
	return primaryTable[m.primaryState()]
}

func (m Model) primaryActionLabel() string {
	return m.primary().label
}

func (m Model) primaryActionName() string {
	return m.primary().name
}

func (m Model) primaryText() string {
	return m.primary().text
}

func (m Model) value(key, fallback string) string {
	return m.status.Value(key, fallback)
}

func (m Model) bool(key string) bool {
	return m.status.Bool(key)
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

func (m Model) helpItems() []string {
	items := []string{
		ui.HelpItem("enter", strings.ToLower(m.primaryActionLabel())),
	}
	state := m.primaryState()
	switch state {
	case "ready":
		items = append(items, ui.HelpItem("w", "console"), ui.HelpItem("x", "stop"), ui.HelpItem("d", "remove"))
	case "stopped":
		items = append(items, ui.HelpItem("s", "start only"), ui.HelpItem("d", "remove"))
	case "booting":
		if m.running() {
			items = append(items, ui.HelpItem("w", "console"), ui.HelpItem("x", "stop"))
		}
	case "repair":
		if m.configured() {
			items = append(items, ui.HelpItem("d", "remove"))
		}
	}
	items = append(items, ui.HelpItem("r", "refresh"), ui.HelpItem("q", "quit"))
	return items
}

func (m Model) vmState() string {
	phase := strings.ToLower(m.value("phase", ""))
	container := strings.ToLower(m.value("container", ""))
	if m.hasSystemBlocker() || phase == "error" {
		return "error"
	}
	if container == "running" {
		return "running"
	}
	if !m.configured() || container == "missing" || container == "exited" || container == "stopped" {
		return "stopped"
	}
	return "unknown"
}

func (m Model) vmStateLabel() string {
	switch m.vmState() {
	case "running":
		if m.ready() {
			return "Running"
		}
		return "Starting"
	case "stopped":
		if !m.configured() {
			return "Not installed"
		}
		return "Stopped"
	case "error":
		return "Fault"
	default:
		return "Unknown"
	}
}


