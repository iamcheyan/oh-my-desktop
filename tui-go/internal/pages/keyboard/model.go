package keyboard

import (
	"encoding/json"
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"github.com/iamcheyan/oh-my-desktop/tui-go/internal/backend"
	"github.com/iamcheyan/oh-my-desktop/tui-go/internal/ui"
)

type status map[string]string

type device struct {
	HyprName    string `json:"hyprName"`
	RawName     string `json:"rawName"`
	DisplayName string `json:"displayName"`
	KeydID      string `json:"keydId"`
	Layout      string `json:"layout"`
	Main        bool   `json:"main"`
	Connected   bool   `json:"connected"`
}

type preset struct {
	ID          string
	Label       string
	Description string
	Type        string
	Source      string
	Target      string
}

type statusMsg struct {
	values status
	err    error
}

type actionMsg struct {
	action string
	err    error
}

type Model struct {
	backend      backend.Backend
	status       status
	devices      []device
	presets      []preset
	fnrow        status
	profileCache map[string]string
	width        int
	height       int
	busy         bool
	err          string
	message      string
	selectedDev  int
	selectedPre  int
	focusPanel   int
	keyChoices   []string
	selectedKey  int
}

func New(b backend.Backend) Model {
	return Model{backend: b}
}

func (m Model) Init() tea.Cmd {
	return m.fetchStatus()
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
	case tea.MouseMsg:
		// mouse handling left intentionally minimal; keyboard-driven UI
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c", "esc":
			return m, tea.Quit
		case "tab":
			if m.focusPanel == 0 {
				m.focusPanel = 1
			} else {
				m.focusPanel = 0
			}
		case "up", "k":
			if m.focusPanel == 1 {
				if m.selectedPre > 0 {
					m.selectedPre--
					m.syncSelectedKey()
				}
			} else {
				if m.selectedDev > 0 {
					m.selectedDev--
					m.syncSelectedKey()
				}
			}
		case "down", "j":
			if m.focusPanel == 1 {
				if m.selectedPre < len(m.presets)-1 {
					m.selectedPre++
					m.syncSelectedKey()
				}
			} else {
				if m.selectedDev < len(m.devices)-1 {
					m.selectedDev++
					m.syncSelectedKey()
				}
			}
		case "left", "h":
			m.focusPanel = 0
		case "right", "l":
			m.focusPanel = 1
		case "r":
			return m, m.fetchStatus()
		case "s":
			if !m.busy {
				m.busy = true
				return m, m.runAction("setup")
			}
		case "a":
			if !m.busy {
				m.busy = true
				return m, m.runAction("apply")
			}
		case "f":
			if !m.busy {
				m.busy = true
				return m, m.nextFnRow()
			}
		case "d":
			if !m.busy && m.hasSelection() && !m.devices[m.selectedDev].Connected {
				m.busy = true
				return m, m.deleteDevice(m.devices[m.selectedDev].HyprName)
			}
		case "[", "-":
			m.stepKey(-1)
		case "]", "=":
			m.stepKey(1)
		case "o":
			if !m.busy && m.hasSelection() && m.selectedPre >= 0 && m.selectedPre < len(m.presets) {
				p := m.presets[m.selectedPre]
				if p.Type == "remap" && len(m.keyChoices) > 0 {
					m.busy = true
					return m, m.setOverride(m.devices[m.selectedDev].HyprName, p.ID, m.keyChoices[m.selectedKey])
				}
			}
		case "O":
			if !m.busy && m.hasSelection() && m.selectedPre >= 0 && m.selectedPre < len(m.presets) {
				p := m.presets[m.selectedPre]
				if p.Type == "remap" {
					m.busy = true
					return m, m.setOverride(m.devices[m.selectedDev].HyprName, p.ID, "")
				}
			}
		case "e":
			if !m.busy && m.hasSelection() {
				hypr := m.devices[m.selectedDev].HyprName
				enabled := m.deviceEnabled(hypr)
				m.busy = true
				if enabled {
					return m, m.setDevice(hypr, "disable")
				}
				return m, m.setDevice(hypr, "enable")
			}
		case "enter", "space", "p":
			if !m.busy && m.hasSelection() && m.selectedPre >= 0 && m.selectedPre < len(m.presets) {
				hypr := m.devices[m.selectedDev].HyprName
				if m.selectedDev < 0 || m.selectedDev >= len(m.devices) {
					return m, nil
				}
				id := m.presets[m.selectedPre].ID
				if m.presetEnabled(hypr, id) {
					m.busy = true
					return m, m.setPreset(hypr, id, "preset-disable")
				}
				m.busy = true
				return m, m.setPreset(hypr, id, "preset-enable")
			}
		}
	case statusMsg:
		if msg.err != nil {
			m.err = msg.err.Error()
		} else {
			m.status = msg.values
			m.err = ""
			m.parseLists()
			m.parseProfileCache()
			m.mergeProfileDevices()
			m.syncSelectedKey()
		}
	case actionMsg:
		m.busy = false
		if msg.err != nil {
			m.err = msg.err.Error()
			m.message = "Action failed"
		} else {
			m.message = "Done"
		}
		return m, m.fetchStatus()
	}
	return m, nil
}

func (m Model) hasSelection() bool {
	return m.selectedDev >= 0 && m.selectedDev < len(m.devices)
}

func (m Model) parseLists() {
	var devs []device
	for _, l := range strings.Split(m.status["__raw__"], "\n") {
		if !strings.HasPrefix(l, "device=") {
			continue
		}
		raw := strings.TrimPrefix(l, "device=")
		var d device
		if err := json.Unmarshal([]byte(raw), &d); err == nil {
			if d.DisplayName == "" {
				d.DisplayName = d.HyprName
			}
			devs = append(devs, d)
		}
	}
	m.devices = devs
	if m.selectedDev >= len(m.devices) {
		m.selectedDev = len(m.devices) - 1
	}
	if m.selectedDev < 0 {
		m.selectedDev = 0
	}

	var presets []preset
	for _, l := range strings.Split(m.status["__raw__"], "\n") {
		if !strings.HasPrefix(l, "preset=") {
			continue
		}
		raw := strings.TrimPrefix(l, "preset=")
		parts := strings.Split(raw, "|")
		if len(parts) < 4 {
			continue
		}
		presets = append(presets, preset{
			ID:          parts[0],
			Label:       parts[1],
			Description: parts[2],
			Type:        parts[3],
			Source:      partAt(parts, 4),
			Target:      partAt(parts, 5),
		})
	}
	m.presets = presets
	if m.selectedPre >= len(m.presets) {
		m.selectedPre = len(m.presets) - 1
	}
	if m.selectedPre < 0 {
		m.selectedPre = 0
	}

	// fnrow
	m.fnrow = status{}
	for _, l := range strings.Split(m.status["__raw__"], "\n") {
		if !strings.HasPrefix(l, "fnrow.") {
			continue
		}
		pair := strings.TrimPrefix(l, "fnrow.")
		kv := strings.SplitN(pair, "=", 2)
		if len(kv) == 2 {
			m.fnrow[kv[0]] = kv[1]
		}
	}

	var keys []string
	for _, l := range strings.Split(m.status["__raw__"], "\n") {
		if strings.HasPrefix(l, "key=") {
			keys = append(keys, strings.TrimPrefix(l, "key="))
		}
	}
	m.keyChoices = keys
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
		panelGap       = 2
		panelBorderW   = 2
		panelBorderH   = 2
		panelPadW      = 4
		panelPadH      = 2
		fixedRows      = 2
	)

	panelInnerW := (width - screenPaddingX - panelGap - panelBorderW*2 - panelPadW*2) / 2
	if panelInnerW < 20 {
		panelInnerW = 20
	}
	panelInnerH := height - screenPaddingY - fixedRows - panelBorderH - panelPadH
	if panelInnerH < 8 {
		panelInnerH = 8
	}
	panelBoxW := panelInnerW + panelPadW
	panelBoxH := panelInnerH + panelPadH

	header := ui.Title.Render("Input") + " " + ui.MutedText.Render(">") + " " + ui.Title.Render("Keyboard remap")
	if m.busy {
		header += " " + ui.OKText.Render("working...")
	}
	if m.err != "" {
		header += " " + ui.DangerText.Render(m.err)
	}
	if m.message != "" && !m.busy {
		header += " " + ui.OKText.Render(m.message)
	}

	left := ui.PanelBox.Width(panelBoxW).Height(panelBoxH).Render(
		ui.PreserveBackground(ui.FitBlock(m.deviceView(panelInnerW), panelInnerW, panelInnerH), ui.Panel),
	)
	right := ui.PanelBox.Width(panelBoxW).Height(panelBoxH).Render(
		ui.PreserveBackground(ui.FitBlock(m.presetView(panelInnerW), panelInnerW, panelInnerH), ui.Panel),
	)

	help := ui.HelpText(
		ui.HelpItem("tab", "focus"),
		ui.HelpItem("enter/p", "toggle preset"),
		ui.HelpItem("e", "enable device"),
		ui.HelpItem("o", "set target"),
		ui.HelpItem("O", "reset target"),
		ui.HelpItem("[/]", "target"),
		ui.HelpItem("f", "fn row"),
		ui.HelpItem("a", "apply"),
		ui.HelpItem("r", "refresh"),
		ui.HelpItem("q", "quit"),
	)
	if m.busy {
		help = ui.OKText.Render("working...")
	}

	return ui.Screen.Padding(1, 2).Render(
		lipgloss.JoinVertical(lipgloss.Left,
			header,
			lipgloss.JoinHorizontal(lipgloss.Top, left, "  ", right),
			help,
		),
	)
}

func (m Model) deviceView(width int) string {
	if m.status == nil {
		return "Loading..."
	}
	health := m.healthTitle()
	detail := m.healthDetail()

	lines := []string{
		lipgloss.JoinHorizontal(lipgloss.Top,
			ui.MiniPreview("Keyboard", health, min(30, max(20, width/3))),
			"  ",
			strings.Join([]string{
				ui.Title.Render("Keyboard remap"),
				ui.MutedText.Render(ui.TruncateStyled(detail, max(20, width-34))),
				"",
				lipgloss.JoinHorizontal(lipgloss.Top,
					ui.StatusPill("keyd", m.bool("keydReady")),
					ui.StatusPill("pending", m.hasPending()),
					ui.StatusPill(focusName(m.focusPanel), true),
				),
			}, "\n"),
		),
		"",
		ui.Section.Render("Service"),
		m.serviceButtons(),
		"",
	}
	if m.fnrow["available"] == "true" {
		lines = append(lines,
			ui.Section.Render("MacBook function row"),
			ui.Row("Mode", m.fnrow["mode"], width),
			ui.MutedText.Render(ui.TruncateStyled("f cycles media → function → auto", width)),
			"",
		)
	}

	if len(m.devices) == 0 {
		lines = append(lines, ui.MutedText.Render(ui.TruncateStyled("No keyboards found. Refresh after connecting.", width)))
		return strings.Join(lines, "\n")
	}

	lines = append(lines, ui.Section.Render("Keyboards"))
	for i, d := range m.devices {
		cursor := "  "
		style := lipgloss.NewStyle().Foreground(ui.Text)
		if i == m.selectedDev {
			cursor = ui.OKText.Render("▶ ")
			style = style.Bold(true)
		}
		statusMark := ui.SubtleText.Render("saved")
		if !d.Connected {
			statusMark = ui.WarnText.Render("disconnected")
		}
		if d.KeydID == "" {
			statusMark = ui.WarnText.Render("missing keyd id")
		}
		label := style.Render(ui.TruncateStyled(fmt.Sprintf("%s%s", cursor, d.DisplayName), width-lipgloss.Width(statusMark)-4))
		lines = append(lines, label+"  "+statusMark)
		if i == m.selectedDev {
			sub := ui.SubtleText.Render(ui.TruncateStyled("   "+(orEmpty(d.KeydID)+" · "+presetCountText(m, d.HyprName)), width))
			lines = append(lines, sub)
		}
	}
	return strings.Join(lines, "\n")
}

func (m Model) presetView(width int) string {
	if !m.hasSelection() {
		return ui.MutedText.Render("Select a keyboard on the left to enable presets.")
	}
	d := m.devices[m.selectedDev]
	enabled := m.deviceEnabled(d.HyprName)

	lines := []string{
		ui.Title.Render(d.DisplayName),
		lipgloss.JoinHorizontal(lipgloss.Top,
			ui.StatusPill(onOff(enabled), enabled),
			ui.StatusPill(fmt.Sprintf("%d presets", presetCount(m, d.HyprName)), presetCount(m, d.HyprName) > 0),
			ui.StatusPill(focusName(m.focusPanel)+" focus", m.focusPanel == 1),
		),
		"",
		ui.Section.Render("Presets"),
	}

	if len(m.presets) == 0 {
		lines = append(lines, ui.MutedText.Render("No presets defined."))
		return strings.Join(lines, "\n")
	}

	for i, p := range m.presets {
		cursor := "  "
		style := lipgloss.NewStyle().Foreground(ui.Text)
		if i == m.selectedPre {
			cursor = ui.OKText.Render("▶ ")
			style = style.Bold(true)
		}
		active := m.presetEnabled(d.HyprName, p.ID)
		mark := ui.SubtleText.Render("off")
		if active {
			mark = ui.OKText.Render("on")
		}
		label := style.Render(ui.TruncateStyled(fmt.Sprintf("%s%s", cursor, p.Label), width-lipgloss.Width(mark)-4))
		lines = append(lines, label+"  "+mark)
		if i == m.selectedPre {
			detail := p.Description
			if p.Type == "remap" {
				target := m.presetOverride(d.HyprName, p.ID)
				if target == "" {
					target = p.Target
				}
				custom := ""
				if m.presetOverride(d.HyprName, p.ID) != "" {
					custom = " (custom)"
				}
				detail = fmt.Sprintf("%s → %s%s · selected target: %s", p.Source, target, custom, m.currentKeyChoice())
			}
			lines = append(lines, ui.SubtleText.Render(ui.TruncateStyled("   "+detail, width)))
		}
	}

	lines = append(lines, "", ui.HelpText(ui.HelpItem("enter/p", "toggle"), ui.HelpItem("o", "set target"), ui.HelpItem("O", "reset")))
	return strings.Join(lines, "\n")
}

func (m Model) serviceButtons() string {
	setupBtn := ui.Button.Render(ui.ActionText("a", "Apply"))
	if m.busy {
		setupBtn = ui.DisabledButton.Render(ui.ActionText("a", "Apply"))
	}
	refreshBtn := ui.Button.Render(ui.ActionText("r", "Refresh"))
	if m.busy {
		refreshBtn = ui.DisabledButton.Render(ui.ActionText("r", "Refresh"))
	}
	return lipgloss.JoinHorizontal(lipgloss.Top, setupBtn, refreshBtn)
}

func (m Model) healthTitle() string {
	if m.value("state", "") == "setup" {
		return "Needs setup"
	}
	if !m.bool("keydReady") {
		return "keyd not ready"
	}
	if m.hasPending() {
		return "Pending changes"
	}
	return "Ready"
}

func (m Model) healthDetail() string {
	n := len(m.devices)
	devices := fmt.Sprintf("%d keyboard%s", n, plural(n))
	if m.err != "" {
		return m.err
	}
	if !m.bool("keydReady") {
		return devices + " · check keyd service"
	}
	return devices + " · config matches this page"
}

func (m Model) hasPending() bool {
	return m.bool("hasPending")
}

func (m Model) deviceEnabled(hypr string) bool {
	return m.profileCache[hypr+".enabled"] != "false"
}

func (m Model) presetEnabled(hypr, id string) bool {
	for _, p := range strings.Fields(m.profileCache[hypr+".enabledPresets"]) {
		if p == id {
			return true
		}
	}
	return false
}

func (m Model) parseProfileCache() {
	m.profileCache = map[string]string{}
	for _, l := range strings.Split(m.status["__raw__"], "\n") {
		if !strings.HasPrefix(l, "profile.") {
			continue
		}
		pair := strings.TrimPrefix(l, "profile.")
		kv := strings.SplitN(pair, "=", 2)
		if len(kv) == 2 {
			m.profileCache[kv[0]] = kv[1]
		}
	}
}

func (m *Model) mergeProfileDevices() {
	seen := map[string]bool{}
	for i := range m.devices {
		m.devices[i].Connected = true
		seen[m.devices[i].HyprName] = true
	}
	prefix := ""
	for key := range m.profileCache {
		if !strings.HasSuffix(key, ".displayName") {
			continue
		}
		prefix = strings.TrimSuffix(key, ".displayName")
		if seen[prefix] {
			continue
		}
		m.devices = append(m.devices, device{
			HyprName:    prefix,
			RawName:     prefix,
			DisplayName: m.profileCache[prefix+".displayName"],
			KeydID:      m.profileCache[prefix+".keydId"],
			Connected:   false,
		})
	}
	if m.selectedDev >= len(m.devices) {
		m.selectedDev = len(m.devices) - 1
	}
	if m.selectedDev < 0 {
		m.selectedDev = 0
	}
}

func (m Model) fetchStatus() tea.Cmd {
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-keyboard", "status")
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
		result := m.backend.Run("omd-settings-keyboard", action)
		return actionMsg{action: action, err: result.Err}
	}
}

func (m Model) setDevice(hypr, mode string) tea.Cmd {
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-keyboard", mode, hypr)
		return actionMsg{action: mode + " " + hypr, err: result.Err}
	}
}

func (m Model) setPreset(hypr, id, op string) tea.Cmd {
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-keyboard", op, hypr, id)
		return actionMsg{action: op + " " + hypr + " " + id, err: result.Err}
	}
}

func (m Model) setOverride(hypr, id, target string) tea.Cmd {
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-keyboard", "preset-override", hypr, id, target)
		return actionMsg{action: "preset-override " + hypr + " " + id, err: result.Err}
	}
}

func (m Model) deleteDevice(hypr string) tea.Cmd {
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-keyboard", "delete", hypr)
		return actionMsg{action: "delete " + hypr, err: result.Err}
	}
}

func (m Model) nextFnRow() tea.Cmd {
	current := m.fnrow["mode"]
	next := "media"
	switch current {
	case "media":
		next = "function"
	case "function":
		next = "auto"
	case "auto":
		next = "media"
	}
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-keyboard", "fnrow", next)
		return actionMsg{action: "fnrow " + next, err: result.Err}
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

func orEmpty(s string) string {
	if s == "" {
		return "no keyd id"
	}
	return s
}

func plural(n int) string {
	if n == 1 {
		return ""
	}
	return "s"
}

func onOff(b bool) string {
	if b {
		return "enabled"
	}
	return "disabled"
}

func presetCount(m Model, hypr string) int {
	return len(strings.Fields(m.profileCache[hypr+".enabledPresets"]))
}

func presetCountText(m Model, hypr string) string {
	c := presetCount(m, hypr)
	return fmt.Sprintf("%d preset%s", c, plural(c))
}

func (m Model) presetOverride(hypr, id string) string {
	return m.profileCache[hypr+".override."+id]
}

func (m *Model) syncSelectedKey() {
	if len(m.keyChoices) == 0 || !m.hasSelection() || len(m.presets) == 0 {
		m.selectedKey = 0
		return
	}
	p := m.presets[m.selectedPre]
	target := m.presetOverride(m.devices[m.selectedDev].HyprName, p.ID)
	if target == "" {
		target = p.Target
	}
	for i, key := range m.keyChoices {
		if key == target {
			m.selectedKey = i
			return
		}
	}
	if m.selectedKey >= len(m.keyChoices) {
		m.selectedKey = len(m.keyChoices) - 1
	}
	if m.selectedKey < 0 {
		m.selectedKey = 0
	}
}

func (m *Model) stepKey(delta int) {
	if len(m.keyChoices) == 0 {
		return
	}
	m.selectedKey += delta
	if m.selectedKey < 0 {
		m.selectedKey = len(m.keyChoices) - 1
	}
	if m.selectedKey >= len(m.keyChoices) {
		m.selectedKey = 0
	}
}

func (m Model) currentKeyChoice() string {
	if len(m.keyChoices) == 0 || m.selectedKey < 0 || m.selectedKey >= len(m.keyChoices) {
		return "-"
	}
	return m.keyChoices[m.selectedKey]
}

func focusName(panel int) string {
	if panel == 0 {
		return "devices"
	}
	return "presets"
}

func partAt(parts []string, idx int) string {
	if idx < len(parts) {
		return parts[idx]
	}
	return ""
}
