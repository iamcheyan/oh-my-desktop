package keyboard

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"github.com/iamcheyan/oh-my-desktop/tui-go/internal/backend"
	"github.com/iamcheyan/oh-my-desktop/tui-go/internal/ui"
)

type Profile struct {
	DisplayName     string            `json:"displayName"`
	HyprName        string            `json:"hyprName"`
	KeydID          string            `json:"keydId"`
	Enabled         bool              `json:"enabled"`
	EnabledPresets  []string          `json:"enabledPresets"`
	PresetOverrides map[string]string `json:"presetOverrides"`
}

type Profiles struct {
	Version int                 `json:"version"`
	Devices map[string]*Profile `json:"devices"`
}

type Device struct {
	HyprName    string `json:"hyprName"`
	RawName     string `json:"rawName"`
	DisplayName string `json:"displayName"`
	KeydID      string `json:"keydId"`
	Layout      string `json:"layout"`
	Main        bool   `json:"main"`
	Connected   bool   `json:"connected"`
}

type Preset struct {
	ID          string
	Label       string
	Description string
	Type        string // "swap" or "remap"
	DefaultTo   string
}

var globalPresetChoices = []Preset{
	{ID: "alt-win-swap", Label: "Swap Left Alt / Win", Description: "Applies left Alt <-> left Win.", Type: "swap"},
	{ID: "ctrl-caps-swap", Label: "Swap Ctrl / Caps", Description: "Applies left Ctrl <-> Caps Lock.", Type: "swap"},
	{ID: "grave-esc-swap", Label: "Swap Grave / Esc", Description: "Swaps the Grave (`) and Escape keys.", Type: "swap"},
	{ID: "caps-esc", Label: "Caps to Esc", Description: "Makes Caps Lock send Escape.", Type: "remap"},
	{ID: "muhenkan-meta", Label: "Muhenkan → Custom", Description: "Makes Muhenkan key send custom key.", Type: "remap", DefaultTo: "leftmeta"},
	{ID: "kana-left", Label: "Katakana/Hiragana to Left", Description: "Makes Katakana/Hiragana key send Left.", Type: "remap", DefaultTo: "left"},
	{ID: "rightalt-down", Label: "Right Alt to Down", Description: "Makes Right Alt send Down.", Type: "remap", DefaultTo: "down"},
	{ID: "rightmeta-down", Label: "Right Win to Down", Description: "Makes Right Super (Win) send Down.", Type: "remap", DefaultTo: "down"},
	{ID: "delete-right", Label: "Delete to Right", Description: "Makes Delete key send Right.", Type: "remap", DefaultTo: "right"},
	{ID: "rightctrl-up", Label: "Right Ctrl to Up", Description: "Makes Right Ctrl send Up.", Type: "remap", DefaultTo: "up"},
}

type Key struct {
	Label string
	Code  string
	W     int
}

var keyboardRows = [][]Key{
	{
		{Label: "Esc", Code: "escape", W: 5},
		{Label: "F1", Code: "f1", W: 4}, {Label: "F2", Code: "f2", W: 4},
		{Label: "F3", Code: "f3", W: 4}, {Label: "F4", Code: "f4", W: 4},
		{Label: "F5", Code: "f5", W: 4}, {Label: "F6", Code: "f6", W: 4},
		{Label: "F7", Code: "f7", W: 4}, {Label: "F8", Code: "f8", W: 4},
		{Label: "F9", Code: "f9", W: 4}, {Label: "F10", Code: "f10", W: 4},
		{Label: "F11", Code: "f11", W: 4}, {Label: "F12", Code: "f12", W: 4},
	},
	{
		{Label: "`", Code: "grave", W: 3}, {Label: "1", Code: "1", W: 3},
		{Label: "2", Code: "2", W: 3}, {Label: "3", Code: "3", W: 3},
		{Label: "4", Code: "4", W: 3}, {Label: "5", Code: "5", W: 3},
		{Label: "6", Code: "6", W: 3}, {Label: "7", Code: "7", W: 3},
		{Label: "8", Code: "8", W: 3}, {Label: "9", Code: "9", W: 3},
		{Label: "0", Code: "0", W: 3}, {Label: "-", Code: "-", W: 3},
		{Label: "=", Code: "=", W: 3}, {Label: "BkSp", Code: "backspace", W: 6},
	},
	{
		{Label: "Tab", Code: "tab", W: 5},
		{Label: "Q", Code: "q", W: 3}, {Label: "W", Code: "w", W: 3},
		{Label: "E", Code: "e", W: 3}, {Label: "R", Code: "r", W: 3},
		{Label: "T", Code: "t", W: 3}, {Label: "Y", Code: "y", W: 3},
		{Label: "U", Code: "u", W: 3}, {Label: "I", Code: "i", W: 3},
		{Label: "O", Code: "o", W: 3}, {Label: "P", Code: "p", W: 3},
		{Label: "[", Code: "[", W: 3}, {Label: "]", Code: "]", W: 3},
		{Label: "\\", Code: "\\", W: 4},
	},
	{
		{Label: "Caps", Code: "capslock", W: 6},
		{Label: "A", Code: "a", W: 3}, {Label: "S", Code: "s", W: 3},
		{Label: "D", Code: "d", W: 3}, {Label: "F", Code: "f", W: 3},
		{Label: "G", Code: "g", W: 3}, {Label: "H", Code: "h", W: 3},
		{Label: "J", Code: "j", W: 3}, {Label: "K", Code: "k", W: 3},
		{Label: "L", Code: "l", W: 3}, {Label: ";", Code: ";", W: 3},
		{Label: "'", Code: "'", W: 3}, {Label: "Enter", Code: "enter", W: 7},
	},
	{
		{Label: "Shift", Code: "leftshift", W: 8},
		{Label: "Z", Code: "z", W: 3}, {Label: "X", Code: "x", W: 3},
		{Label: "C", Code: "c", W: 3}, {Label: "V", Code: "v", W: 3},
		{Label: "B", Code: "b", W: 3}, {Label: "N", Code: "n", W: 3},
		{Label: "M", Code: "m", W: 3}, {Label: ",", Code: ",", W: 3},
		{Label: ".", Code: ".", W: 3}, {Label: "/", Code: "/", W: 3},
		{Label: "Shift", Code: "rightshift", W: 8},
	},
	{
		{Label: "Ctrl", Code: "leftcontrol", W: 6}, {Label: "Win", Code: "leftmeta", W: 5},
		{Label: "Alt", Code: "leftalt", W: 5}, {Label: "Space", Code: "space", W: 16},
		{Label: "Alt", Code: "rightalt", W: 5}, {Label: "Win", Code: "rightmeta", W: 5},
		{Label: "Menu", Code: "menu", W: 5}, {Label: "Ctrl", Code: "rightcontrol", W: 6},
	},
	{
		{Label: "F13", Code: "f13", W: 5}, {Label: "F14", Code: "f14", W: 5},
		{Label: "F15", Code: "f15", W: 5}, {Label: "F16", Code: "f16", W: 5},
		{Label: "F17", Code: "f17", W: 5}, {Label: "F18", Code: "f18", W: 5},
		{Label: "F19", Code: "f19", W: 5}, {Label: "F20", Code: "f20", W: 5},
		{Label: "F21", Code: "f21", W: 5}, {Label: "F22", Code: "f22", W: 5},
		{Label: "F23", Code: "f23", W: 5}, {Label: "F24", Code: "f24", W: 5},
	},
	{
		{Label: "Up", Code: "up", W: 5}, {Label: "Down", Code: "down", W: 6},
		{Label: "Left", Code: "left", W: 6}, {Label: "Right", Code: "right", W: 7},
		{Label: "Delete", Code: "delete", W: 8}, {Label: "Mute", Code: "mute", W: 6},
		{Label: "VolDn", Code: "volumedown", W: 7}, {Label: "VolUp", Code: "volumeup", W: 7},
	},
}

type palette struct {
	background lipgloss.Color
	panel      lipgloss.Color
	panelSoft  lipgloss.Color
	line       lipgloss.Color
	lineSoft   lipgloss.Color
	text       lipgloss.Color
	muted      lipgloss.Color
	subtle     lipgloss.Color
	accent     lipgloss.Color
}

type Model struct {
	backend            backend.Backend
	busy               bool
	status             backend.Status
	message            string
	devices            []Device
	selectedDeviceIdx  int
	focusArea          int // 0: keyboard list, 1: profile settings presets list
	selectedPresetIdx  int
	showPicker         bool
	pickerPresetID     string
	pickerRow          int
	pickerCol          int
	profiles           Profiles
	width              int
	height             int
}

func New(b backend.Backend) Model {
	m := Model{
		backend:           b,
		selectedDeviceIdx: 0,
		focusArea:         0,
		selectedPresetIdx: 0,
		showPicker:        false,
	}
	m.loadProfiles()
	return m
}

func (m *Model) loadProfiles() {
	profilesPath := filepath.Join(m.backend.Root, "keyboard-remap", "profiles.json")
	m.profiles = Profiles{Version: 1, Devices: make(map[string]*Profile)}
	if content, err := os.ReadFile(profilesPath); err == nil {
		_ = json.Unmarshal(content, &m.profiles)
	}
}

func (m *Model) saveProfiles() {
	profilesPath := filepath.Join(m.backend.Root, "keyboard-remap", "profiles.json")
	if data, err := json.MarshalIndent(m.profiles, "", "  "); err == nil {
		_ = os.WriteFile(profilesPath, data, 0644)
	}
}

func (m Model) Init() tea.Cmd {
	return tea.Batch(m.fetchStatus(), m.fetchDevices())
}

func (m Model) fetchStatus() tea.Cmd {
	return func() tea.Msg {
		res := m.backend.Run("omd-settings-keyboard", "status")
		return backend.StatusMsg{Values: backend.ParseStatus(res.Lines), Err: res.Err}
	}
}

func (m Model) fetchDevices() tea.Cmd {
	return func() tea.Msg {
		res := m.backend.Run("../share/bin/omarchy-keyboard-list")
		var dev []Device
		if len(res.Lines) > 0 {
			_ = json.Unmarshal([]byte(strings.Join(res.Lines, "\n")), &dev)
		}
		return devMsg{devices: dev}
	}
}

type devMsg struct {
	devices []Device
}

func (m Model) runAction(action string) tea.Cmd {
	return func() tea.Msg {
		res := m.backend.Run("omd-settings-keyboard", action)
		return backend.ActionMsg{Action: action, Err: res.Err}
	}
}

func (m Model) palette() palette {
	return palette{
		background: ui.Background,
		panel:      ui.Panel,
		panelSoft:  ui.PanelSoft,
		line:       ui.Line,
		lineSoft:   ui.LineSoft,
		text:       ui.Text,
		muted:      ui.Muted,
		subtle:     ui.Subtle,
		accent:     ui.Accent,
	}
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil

	case backend.StatusMsg:
		m.busy = false
		m.status = msg.Values
		return m, nil

	case devMsg:
		m.busy = false
		m.mergeDevices(msg.devices)
		return m, nil

	case backend.ActionMsg:
		m.busy = false
		if msg.Err == nil {
			m.message = keyboardActionMessage(msg.Action)
		} else {
			m.message = "Failed: " + msg.Err.Error()
		}
		return m, m.fetchStatus()

	case tea.KeyMsg:
		if m.showPicker {
			return m.handlePickerKey(msg.String())
		}
		return m.handleMainKey(msg.String())

	case tea.MouseMsg:
		if msg.Type == tea.MouseRelease && msg.Button == tea.MouseButtonLeft {
			if m.showPicker {
				return m.handlePickerClick(msg.X, msg.Y)
			}
			return m.handleMainClick(msg.X, msg.Y)
		}
	}
	return m, nil
}

func (m *Model) mergeDevices(connected []Device) {
	m.devices = nil
	connectedMap := make(map[string]bool)
	for _, dev := range connected {
		dev.Connected = true
		m.devices = append(m.devices, dev)
		connectedMap[dev.HyprName] = true
	}
	for name, prof := range m.profiles.Devices {
		if connectedMap[name] {
			continue
		}
		m.devices = append(m.devices, Device{
			HyprName:    prof.HyprName,
			RawName:     prof.HyprName,
			DisplayName: prof.DisplayName,
			KeydID:      prof.KeydID,
			Connected:   false,
		})
	}
	sort.Slice(m.devices, func(i, j int) bool {
		if m.devices[i].Connected != m.devices[j].Connected {
			return m.devices[i].Connected
		}
		return m.devices[i].DisplayName < m.devices[j].DisplayName
	})
}

func keyboardActionMessage(action string) string {
	switch action {
	case "setup":
		return "keyd setup completed"
	case "apply":
		return "Key remaps applied successfully"
	case "key-test":
		return "Key tester finished"
	default:
		return "Done"
	}
}

func (m Model) handlePickerKey(key string) (tea.Model, tea.Cmd) {
	switch key {
	case "esc":
		m.showPicker = false
	case "up", "k":
		m.pickerRow = max(0, m.pickerRow-1)
		m.pickerCol = min(m.pickerCol, len(keyboardRows[m.pickerRow])-1)
	case "down", "j":
		m.pickerRow = min(len(keyboardRows)-1, m.pickerRow+1)
		m.pickerCol = min(m.pickerCol, len(keyboardRows[m.pickerRow])-1)
	case "left", "h":
		m.pickerCol = max(0, m.pickerCol-1)
	case "right", "l":
		m.pickerCol = min(len(keyboardRows[m.pickerRow])-1, m.pickerCol+1)
	case "enter", " ":
		m.confirmPickerSelection()
	}
	return m, nil
}

func (m *Model) confirmPickerSelection() {
	if m.selectedDeviceIdx >= len(m.devices) {
		m.showPicker = false
		return
	}
	devName := m.devices[m.selectedDeviceIdx].HyprName
	prof := m.profiles.Devices[devName]
	if prof == nil {
		m.showPicker = false
		return
	}

	targetKey := keyboardRows[m.pickerRow][m.pickerCol].Code
	if targetKey != "" {
		if prof.PresetOverrides == nil {
			prof.PresetOverrides = make(map[string]string)
		}
		prof.PresetOverrides[m.pickerPresetID] = targetKey
		m.saveProfiles()
	}
	m.showPicker = false
}

func (m Model) handleMainKey(key string) (tea.Model, tea.Cmd) {
	switch key {
	case "q", "ctrl+c":
		return m, tea.Quit
	case "tab":
		if m.focusArea == 0 {
			m.focusArea = 1
		} else {
			m.focusArea = 0
		}
	case "up", "k":
		if m.focusArea == 0 {
			m.selectedDeviceIdx = max(0, m.selectedDeviceIdx-1)
		} else {
			m.selectedPresetIdx = max(0, m.selectedPresetIdx-1)
		}
	case "down", "j":
		if m.focusArea == 0 {
			m.selectedDeviceIdx = min(len(m.devices)-1, m.selectedDeviceIdx+1)
		} else {
			m.selectedPresetIdx = min(len(globalPresetChoices), m.selectedPresetIdx+1)
		}
	case " ", "space":
		if m.focusArea == 0 {
			m.toggleSelectedProfileEnabled()
		} else {
			if m.selectedPresetIdx == 0 {
				m.toggleSelectedProfileEnabled()
			} else {
				m.toggleSelectedPreset()
			}
		}
	case "enter":
		if m.focusArea == 1 {
			if m.selectedPresetIdx == 0 {
				m.toggleSelectedProfileEnabled()
			} else {
				m.triggerOverridePicker()
			}
		}
	case "a":
		if !m.busy {
			m.busy = true
			return m, m.runAction("apply")
		}
	case "s":
		if !m.busy {
			m.busy = true
			return m, m.runAction("setup")
		}
	case "t":
		if !m.busy {
			m.busy = true
			return m, m.runAction("key-test")
		}
	case "r":
		return m, tea.Batch(m.fetchStatus(), m.fetchDevices())
	}
	return m, nil
}

func (m *Model) toggleSelectedProfileEnabled() {
	if m.selectedDeviceIdx >= len(m.devices) {
		return
	}
	dev := m.devices[m.selectedDeviceIdx]
	prof, exists := m.profiles.Devices[dev.HyprName]
	if !exists {
		prof = &Profile{
			DisplayName:     dev.DisplayName,
			HyprName:        dev.HyprName,
			KeydID:          dev.KeydID,
			Enabled:         true,
			EnabledPresets:  []string{},
			PresetOverrides: make(map[string]string),
		}
		m.profiles.Devices[dev.HyprName] = prof
		m.saveProfiles()
		return
	}
	prof.Enabled = !prof.Enabled
	m.saveProfiles()
}

func (m *Model) toggleSelectedPreset() {
	if m.selectedDeviceIdx >= len(m.devices) {
		return
	}
	devName := m.devices[m.selectedDeviceIdx].HyprName
	prof, exists := m.profiles.Devices[devName]
	if !exists {
		dev := m.devices[m.selectedDeviceIdx]
		prof = &Profile{
			DisplayName:     dev.DisplayName,
			HyprName:        dev.HyprName,
			KeydID:          dev.KeydID,
			Enabled:         true,
			EnabledPresets:  []string{},
			PresetOverrides: make(map[string]string),
		}
		m.profiles.Devices[devName] = prof
	}

	presetIdx := m.selectedPresetIdx - 1
	if presetIdx < 0 || presetIdx >= len(globalPresetChoices) {
		return
	}
	presetID := globalPresetChoices[presetIdx].ID
	foundIdx := -1
	for idx, id := range prof.EnabledPresets {
		if id == presetID {
			foundIdx = idx
			break
		}
	}

	if foundIdx >= 0 {
		prof.EnabledPresets = append(prof.EnabledPresets[:foundIdx], prof.EnabledPresets[foundIdx+1:]...)
	} else {
		prof.EnabledPresets = append(prof.EnabledPresets, presetID)
	}
	m.saveProfiles()
}

func (m *Model) triggerOverridePicker() {
	if m.selectedDeviceIdx >= len(m.devices) {
		return
	}
	presetIdx := m.selectedPresetIdx - 1
	if presetIdx < 0 || presetIdx >= len(globalPresetChoices) {
		return
	}
	preset := globalPresetChoices[presetIdx]
	if preset.Type != "remap" {
		return
	}

	m.pickerPresetID = preset.ID
	m.showPicker = true
	m.pickerRow = 0
	m.pickerCol = 0
}

func (m Model) handlePickerClick(clickX, clickY int) (tea.Model, tea.Cmd) {
	viewStr := m.View()
	lines := strings.Split(viewStr, "\n")
	if clickY < 0 || clickY >= len(lines) {
		return m, nil
	}

	var ansiRegex = regexp.MustCompile(`\x1b\[[0-9;]*[a-zA-Z]`)
	plainLine := ansiRegex.ReplaceAllString(lines[clickY], "")

	for rIdx, row := range keyboardRows {
		for cIdx, key := range row {
			if key.Label == "" {
				continue
			}
			innerW := key.W - 2
			if innerW < 1 {
				innerW = 1
			}
			padded := key.Label
			if len(padded) > innerW {
				padded = padded[:innerW]
			}
			leftPad := (innerW - len(padded)) / 2
			rightPad := innerW - len(padded) - leftPad
			fullBlockLabel := "[" + strings.Repeat(" ", leftPad) + padded + strings.Repeat(" ", rightPad) + "]"

			idx := strings.Index(plainLine, fullBlockLabel)
			if idx >= 0 {
				if clickX >= idx && clickX < idx+len(fullBlockLabel) {
					m.pickerRow = rIdx
					m.pickerCol = cIdx
					m.confirmPickerSelection()
					return m, nil
				}
			}
		}
	}
	return m, nil
}

func (m Model) handleMainClick(clickX, clickY int) (tea.Model, tea.Cmd) {
	viewStr := m.View()
	lines := strings.Split(viewStr, "\n")
	if clickY < 0 || clickY >= len(lines) {
		return m, nil
	}

	var ansiRegex = regexp.MustCompile(`\x1b\[[0-9;]*[a-zA-Z]`)
	plain := ansiRegex.ReplaceAllString(lines[clickY], "")

	buttons := []struct {
		text string
		key  string
	}{
		{"Setup keyd (s)", "s"},
		{"Apply (a)", "a"},
		{"Discard (x)", "r"},
	}
	for _, b := range buttons {
		idx := strings.Index(plain, b.text)
		if idx >= 0 {
			if clickX >= idx-2 && clickX <= idx+len(b.text)+2 {
				return m.handleMainKey(b.key)
			}
		}
	}

	for i, dev := range m.devices {
		rowText := dev.DisplayName
		idx := strings.Index(plain, rowText)
		if idx >= 0 {
			if clickX >= idx-4 && clickX <= idx+len(rowText)+4 {
				m.selectedDeviceIdx = i
				m.focusArea = 0
				return m, nil
			}
		}
	}

	for i, preset := range globalPresetChoices {
		rowText := preset.Label
		idx := strings.Index(plain, rowText)
		if idx >= 0 {
			if clickX >= idx-4 && clickX <= idx+len(rowText)+4 {
				m.selectedPresetIdx = i + 1
				m.focusArea = 1
				if preset.Type == "remap" {
					targetText := "[ "
					targetIdx := strings.Index(plain, targetText)
					if targetIdx >= 0 && clickX >= targetIdx {
						m.triggerOverridePicker()
						return m, nil
					}
				}
				m.toggleSelectedPreset()
				return m, nil
			}
		}
	}

	idx := strings.Index(plain, "Profile: ")
	if idx >= 0 {
		m.selectedPresetIdx = 0
		m.focusArea = 1
		m.toggleSelectedProfileEnabled()
	}

	return m, nil
}

func (m Model) statusLight() string {
	pal := m.palette()
	style := lipgloss.NewStyle().Foreground(pal.accent)
	if !m.status.Bool("keydRunning") {
		style = lipgloss.NewStyle().Foreground(ui.Danger)
	}
	return style.Render("●")
}

func (m Model) headerView() string {
	title := m.statusLight() + " " + ui.Title.Render("Keyboard Remap")
	if m.busy {
		title += " " + ui.OKText.Render("working…")
	}
	return title
}

func (m Model) View() string {
	pal := m.palette()
	header := m.headerView()

	if m.showPicker {
		pickerView := m.renderPickerView()
		if m.width > 0 && m.height > 0 {
			return lipgloss.Place(m.width, m.height, lipgloss.Center, lipgloss.Center, pickerView)
		}
		return pickerView
	}

	contentW := m.width - 4
	contentH := m.height - 8
	if contentW < 40 {
		contentW = 40
	}
	if contentH < 14 {
		contentH = 14
	}

	content := ui.PreserveBackground(ui.FitBlock(m.contentView(contentW, contentH), contentW, contentH), pal.background)

	helpItems := []string{
		ui.HelpItem("arrows", "navigate"),
		ui.HelpItem("tab", "switch column"),
		ui.HelpItem("space", "toggle"),
		ui.HelpItem("enter", "edit custom key"),
		ui.HelpItem("s", "setup keyd"),
		ui.HelpItem("t", "key tester"),
		ui.HelpItem("r", "refresh"),
		ui.HelpItem("q", "quit"),
	}

	help := ui.HelpText(helpItems...)
	if m.status.Bool("pendingChanges") {
		help = help + "\n" + lipgloss.NewStyle().Foreground(pal.accent).Render("Pending changes:  ○ Apply (a)  ○ Discard (x)")
	}

	parts := []string{content, help}
	if header != "" {
		parts = append([]string{header}, parts...)
	}

	return lipgloss.NewStyle().Background(pal.background).Foreground(pal.text).Padding(1, 1).Render(
		lipgloss.JoinVertical(lipgloss.Left, parts...),
	)
}

func (m Model) renderPickerView() string {
	pal := m.palette()
	var b strings.Builder

	b.WriteString(lipgloss.NewStyle().Bold(true).Foreground(pal.accent).Render("Select Target Key Override"))
	b.WriteString("\n\n")

	for rowIdx, row := range keyboardRows {
		b.WriteString("  ")
		for colIdx, key := range row {
			isSel := m.pickerRow == rowIdx && m.pickerCol == colIdx
			b.WriteString(renderKey(key, isSel, pal))
		}
		b.WriteString("\n")
	}

	b.WriteString("\n")
	b.WriteString(lipgloss.NewStyle().Foreground(pal.muted).Render("  arrows: navigate  |  Enter/Space: select  |  Esc: cancel"))
	b.WriteString("\n")

	return lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(pal.line).
		Background(pal.panel).
		Padding(1, 2).
		Render(b.String())
}

func (m Model) contentView(w, h int) string {
	leftW := 32
	rightW := w - 35
	if rightW < 30 {
		rightW = 30
	}

	leftCol := m.renderLeftColumn(leftW, h)
	rightCol := m.renderRightColumn(rightW, h)

	return lipgloss.JoinHorizontal(lipgloss.Top, leftCol, "   ", rightCol)
}

func (m Model) renderLeftColumn(w, h int) string {
	pal := m.palette()
	var b strings.Builder

	statusText := "keyd: inactive"
	statusOk := false
	if m.status.Bool("keydRunning") {
		statusText = "keyd: active"
		statusOk = true
	}
	b.WriteString(ui.StatusPill(statusText, statusOk))
	b.WriteString("\n\n")

	b.WriteString(ui.Section.Render("CONNECTED KEYBOARDS"))
	b.WriteString("\n")

	for i, dev := range m.devices {
		bullet := "○"
		style := lipgloss.NewStyle()
		if dev.Connected {
			bullet = "●"
			style = style.Foreground(pal.accent)
		} else {
			style = style.Foreground(pal.subtle)
		}

		if m.focusArea == 0 && i == m.selectedDeviceIdx {
			bullet = "🔘"
			if dev.Connected {
				style = lipgloss.NewStyle().Background(pal.accent).Foreground(pal.background).Bold(true)
			} else {
				style = lipgloss.NewStyle().Background(pal.subtle).Foreground(pal.background).Bold(true)
			}
		}

		offlineText := ""
		if !dev.Connected {
			offlineText = " (offline)"
		}

		b.WriteString(fmt.Sprintf("%s %s\n", bullet, style.Render(dev.DisplayName+offlineText)))
	}

	b.WriteString("\n")
	b.WriteString(ui.Section.Render("ACTIONS"))
	b.WriteString("\n")
	b.WriteString(ui.ActionButton("", "s", "Setup keyd", m.busy))
	b.WriteString("\n")
	b.WriteString(ui.ActionButton("", "t", "Key Tester", m.busy))
	b.WriteString("\n")

	return lipgloss.NewStyle().Width(w).Height(h).Render(b.String())
}

func (m Model) renderRightColumn(w, h int) string {
	pal := m.palette()
	var b strings.Builder

	if m.selectedDeviceIdx >= len(m.devices) {
		b.WriteString(lipgloss.NewStyle().Foreground(pal.muted).Render("Select a keyboard device to configure..."))
		return lipgloss.NewStyle().Width(w).Height(h).Render(b.String())
	}

	dev := m.devices[m.selectedDeviceIdx]
	prof, exists := m.profiles.Devices[dev.HyprName]

	isEnabled := exists && prof.Enabled
	enabledBullet := "[ ]"
	if isEnabled {
		enabledBullet = "[X]"
	}

	b.WriteString(ui.Section.Render("KEYBOARD PROFILE"))
	b.WriteString("\n")
	b.WriteString(fmt.Sprintf("Device: %s\n", lipgloss.NewStyle().Foreground(pal.accent).Bold(true).Render(dev.DisplayName)))
	b.WriteString(fmt.Sprintf("ID:     %s\n\n", lipgloss.NewStyle().Foreground(pal.muted).Render(dev.KeydID)))

	profileStyle := lipgloss.NewStyle().Foreground(pal.text)
	if m.focusArea == 1 && m.selectedPresetIdx == 0 {
		profileStyle = lipgloss.NewStyle().Foreground(pal.accent).Bold(true)
	}
	b.WriteString(profileStyle.Render(fmt.Sprintf("Profile: %s Enabled\n\n", enabledBullet)))

	b.WriteString(ui.Section.Render("PRESETS"))
	b.WriteString("\n")

	for i, preset := range globalPresetChoices {
		active := false
		if isEnabled && exists {
			for _, id := range prof.EnabledPresets {
				if id == preset.ID {
					active = true
					break
				}
			}
		}

		bullet := "[ ]"
		if active {
			bullet = "[X]"
		}

		presetStyle := lipgloss.NewStyle().Foreground(pal.text)
		overrideStyle := lipgloss.NewStyle().Foreground(pal.accent)

		if !isEnabled {
			presetStyle = lipgloss.NewStyle().Foreground(pal.subtle)
			overrideStyle = lipgloss.NewStyle().Foreground(pal.subtle)
		}

		if m.focusArea == 1 && m.selectedPresetIdx == i+1 {
			if isEnabled {
				presetStyle = lipgloss.NewStyle().Foreground(pal.accent).Bold(true)
			} else {
				presetStyle = lipgloss.NewStyle().Foreground(pal.muted).Bold(true).Underline(true)
			}
		}

		overrideText := ""
		if preset.Type == "remap" {
			target := preset.DefaultTo
			if exists && prof.PresetOverrides != nil {
				if val, ok := prof.PresetOverrides[preset.ID]; ok && val != "" {
					target = val
				}
			}
			overrideText = fmt.Sprintf("  [ %s ]", target)
		}

		b.WriteString(fmt.Sprintf("%s %s%s\n", bullet, presetStyle.Render(preset.Label), overrideStyle.Render(overrideText)))
	}

	return lipgloss.NewStyle().Width(w).Height(h).Render(b.String())
}

func renderKey(k Key, isSelected bool, pal palette) string {
	content := k.Label
	innerW := k.W - 2
	if innerW < 1 {
		innerW = 1
	}
	if len(content) > innerW {
		content = content[:innerW]
	}
	leftPad := (innerW - len(content)) / 2
	rightPad := innerW - len(content) - leftPad
	padded := strings.Repeat(" ", leftPad) + content + strings.Repeat(" ", rightPad)

	if isSelected {
		return lipgloss.NewStyle().
			Foreground(pal.background).
			Background(pal.accent).
			Bold(true).
			Render("[" + padded + "]")
	}
	return lipgloss.NewStyle().
		Foreground(pal.text).
		Render("[" + padded + "]")
}
