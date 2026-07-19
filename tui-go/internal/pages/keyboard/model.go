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

type Model struct {
	backend           backend.Backend
	busy              bool
	status            backend.Status
	message           string
	devices           []Device
	selectedDeviceIdx int
	focusArea         int // 0: keyboard list, 1: profile settings presets list
	selectedPresetIdx int
	showPicker        bool
	pickerPresetID    string
	pickerRow         int
	pickerCol         int
	profiles          Profiles
	width             int
	height            int
	fnmodeAvailable   bool
	fnmode            string
	fnmodeValue       int
	logs              []string
	scrollOffset      int // log scroll: 0 = pinned to bottom
	lastApplyOK       *bool
}

func New(b backend.Backend) Model {
	m := Model{
		backend:           b,
		selectedDeviceIdx: 0,
		focusArea:         0,
		selectedPresetIdx: 0,
		showPicker:        false,
		logs: []string{
			"Keyboard Remap ready.",
			"Toggle presets, then Apply (a) to write /etc/keyd/omd.conf.",
		},
	}
	m.loadProfiles()
	return m
}

func (m *Model) appendLog(line string) {
	line = strings.TrimSpace(line)
	if line == "" {
		return
	}
	m.logs = append(m.logs, line)
	if len(m.logs) > 200 {
		m.logs = m.logs[len(m.logs)-200:]
	}
	// Pin to bottom on new output.
	m.scrollOffset = 0
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

type fnmodeMsg struct {
	Available bool
	Mode      string
	Value     int
}

func (m Model) Init() tea.Cmd {
	return tea.Batch(m.fetchStatus(), m.fetchDevices(), m.fetchFnmode())
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

func (m Model) fetchFnmode() tea.Cmd {
	return func() tea.Msg {
		res := m.backend.Run("omd-settings-keyboard", "fnmode-status")
		var status struct {
			Available bool   `json:"available"`
			Mode      string `json:"mode"`
			Value     int    `json:"value"`
		}
		if len(res.Lines) > 0 {
			_ = json.Unmarshal([]byte(strings.Join(res.Lines, "\n")), &status)
		}
		return fnmodeMsg{Available: status.Available, Mode: status.Mode, Value: status.Value}
	}
}

func (m Model) setFnmode(mode string) tea.Cmd {
	return func() tea.Msg {
		res := m.backend.Run("omd-settings-keyboard", "fnmode-set", mode)
		return backend.ActionMsg{Action: "fnmode-set", Err: res.Err, Lines: res.Lines}
	}
}

type devMsg struct {
	devices []Device
}

func (m Model) runAction(action string) tea.Cmd {
	return func() tea.Msg {
		res := m.backend.Run("omd-settings-keyboard", action)
		return backend.ActionMsg{Action: action, Err: res.Err, Lines: res.Lines}
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

	case fnmodeMsg:
		m.fnmodeAvailable = msg.Available
		m.fnmode = msg.Mode
		m.fnmodeValue = msg.Value
		return m, nil

	case devMsg:
		m.busy = false
		m.mergeDevices(msg.devices)
		return m, nil

	case backend.ActionMsg:
		m.busy = false
		m.appendLog("$ " + msg.Action)
		for _, line := range msg.Lines {
			m.appendLog(line)
		}
		if msg.Err == nil {
			if msg.Action == "fnmode-set" {
				m.message = "Fn key mode updated"
				m.appendLog("fn mode updated")
			} else {
				m.message = keyboardActionMessage(msg.Action)
				m.appendLog(keyboardActionMessage(msg.Action))
			}
			if msg.Action == "apply" {
				ok := true
				m.lastApplyOK = &ok
			}
		} else {
			m.message = "Failed: " + msg.Err.Error()
			m.appendLog("error: " + msg.Err.Error())
			if msg.Action == "apply" {
				ok := false
				m.lastApplyOK = &ok
			}
		}
		return m, tea.Batch(m.fetchStatus(), m.fetchFnmode())

	case tea.KeyMsg:
		if m.showPicker {
			return m.handlePickerKey(msg.String())
		}
		return m.handleMainKey(msg.String())

	case tea.MouseMsg:
		switch msg.Type {
		case tea.MouseWheelUp:
			m.scrollOffset++
			return m, nil
		case tea.MouseWheelDown:
			if m.scrollOffset > 0 {
				m.scrollOffset--
			}
			return m, nil
		}
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
		connectedMap[deviceIdentity(dev.HyprName)] = true
	}
	for _, prof := range m.profiles.Devices {
		if prof == nil || connectedMap[deviceIdentity(prof.HyprName)] {
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

// Hyprland may append "-keyboard" when the same device is exposed through a
// different connection path. Keep those names attached to one saved profile.
func deviceIdentity(name string) string {
	return strings.TrimSuffix(strings.ToLower(strings.TrimSpace(name)), "-keyboard")
}

func profileWeight(prof *Profile) int {
	if prof == nil {
		return -1
	}
	return len(prof.EnabledPresets)*10 + len(prof.PresetOverrides)
}

func (m Model) profileForDevice(dev Device) (string, *Profile) {
	identity := deviceIdentity(dev.HyprName)
	bestKey := ""
	var best *Profile
	for key, prof := range m.profiles.Devices {
		if prof == nil || deviceIdentity(prof.HyprName) != identity {
			continue
		}
		if best == nil || profileWeight(prof) > profileWeight(best) ||
			(profileWeight(prof) == profileWeight(best) && key == dev.HyprName) {
			bestKey = key
			best = prof
		}
	}
	return bestKey, best
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
	_, prof := m.profileForDevice(m.devices[m.selectedDeviceIdx])
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

func (m Model) rightColRows() int {
	if m.fnmodeAvailable {
		return 1 + 1 + len(globalPresetChoices)
	}
	return 1 + len(globalPresetChoices)
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
			m.selectedPresetIdx = min(m.rightColRows()-1, m.selectedPresetIdx+1)
		}
	case " ", "space":
		if m.focusArea == 0 {
			m.toggleSelectedProfileEnabled()
		} else {
			if m.selectedPresetIdx == 0 {
				m.toggleSelectedProfileEnabled()
			} else if m.fnmodeAvailable && m.selectedPresetIdx == 1 {
				m.busy = true
				return m, m.cycleFnmodeCmd()
			} else {
				m.toggleSelectedPreset()
			}
		}
	case "enter":
		if m.focusArea == 1 {
			if m.selectedPresetIdx == 0 {
				m.toggleSelectedProfileEnabled()
			} else if m.fnmodeAvailable && m.selectedPresetIdx == 1 {
				m.busy = true
				return m, m.cycleFnmodeCmd()
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
	case "f":
		if m.fnmodeAvailable && !m.busy {
			m.busy = true
			return m, m.cycleFnmodeCmd()
		}
	case "c":
		src := m.findCopySourceProfile()
		if src != "" {
			m.copyProfileFrom(src)
		}
	case "r":
		m.appendLog("refresh status / devices")
		return m, tea.Batch(m.fetchStatus(), m.fetchDevices(), m.fetchFnmode())
	case "pgup":
		m.scrollOffset += 3
	case "pgdown":
		if m.scrollOffset > 0 {
			m.scrollOffset -= 3
			if m.scrollOffset < 0 {
				m.scrollOffset = 0
			}
		}
	case "home":
		m.scrollOffset = 9999
	case "end":
		m.scrollOffset = 0
	}
	return m, nil
}

func (m Model) cycleFnmodeCmd() tea.Cmd {
	next := "media"
	switch m.fnmode {
	case "media":
		next = "function"
	case "function":
		next = "auto"
	case "auto":
		next = "media"
	}
	return m.setFnmode(next)
}

func (m *Model) toggleSelectedProfileEnabled() {
	if m.selectedDeviceIdx >= len(m.devices) {
		return
	}
	dev := m.devices[m.selectedDeviceIdx]
	_, prof := m.profileForDevice(dev)
	if prof == nil {
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
		m.appendLog(fmt.Sprintf("created profile for %s (enabled)", dev.DisplayName))
		return
	}
	prof.Enabled = !prof.Enabled
	m.saveProfiles()
	state := "disabled"
	if prof.Enabled {
		state = "enabled"
	}
	m.appendLog(fmt.Sprintf("profile %s %s", dev.DisplayName, state))
}

func (m *Model) toggleSelectedPreset() {
	if m.selectedDeviceIdx >= len(m.devices) {
		return
	}
	dev := m.devices[m.selectedDeviceIdx]
	_, prof := m.profileForDevice(dev)
	if prof == nil {
		prof = &Profile{
			DisplayName:     dev.DisplayName,
			HyprName:        dev.HyprName,
			KeydID:          dev.KeydID,
			Enabled:         true,
			EnabledPresets:  []string{},
			PresetOverrides: make(map[string]string),
		}
		m.profiles.Devices[dev.HyprName] = prof
	}

	presetIdx := m.selectedPresetIdx - 1
	if m.fnmodeAvailable {
		presetIdx = m.selectedPresetIdx - 2
	}

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
		m.appendLog(fmt.Sprintf("preset off: %s", presetID))
	} else {
		prof.EnabledPresets = append(prof.EnabledPresets, presetID)
		m.appendLog(fmt.Sprintf("preset on: %s", presetID))
	}
	m.saveProfiles()
}

func (m *Model) triggerOverridePicker() {
	if m.selectedDeviceIdx >= len(m.devices) {
		return
	}
	presetIdx := m.selectedPresetIdx - 1
	if m.fnmodeAvailable {
		presetIdx = m.selectedPresetIdx - 2
	}

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

func (m *Model) findCopySourceProfile() string {
	if m.selectedDeviceIdx >= len(m.devices) {
		return ""
	}
	dev := m.devices[m.selectedDeviceIdx]
	_, prof := m.profileForDevice(dev)
	if prof != nil && len(prof.EnabledPresets) > 0 {
		return ""
	}

	for name, otherProf := range m.profiles.Devices {
		if otherProf != nil && deviceIdentity(otherProf.HyprName) != deviceIdentity(dev.HyprName) && len(otherProf.EnabledPresets) > 0 {
			return name
		}
	}
	return ""
}

func (m *Model) copyProfileFrom(sourceName string) {
	if m.selectedDeviceIdx >= len(m.devices) || sourceName == "" {
		return
	}
	dev := m.devices[m.selectedDeviceIdx]
	source := m.profiles.Devices[sourceName]
	if source == nil {
		return
	}

	destKey, dest := m.profileForDevice(dev)
	if dest == nil {
		destKey = dev.HyprName
		dest = &Profile{
			DisplayName:     dev.DisplayName,
			HyprName:        dev.HyprName,
			KeydID:          dev.KeydID,
			Enabled:         true,
			EnabledPresets:  []string{},
			PresetOverrides: make(map[string]string),
		}
		m.profiles.Devices[destKey] = dest
	}

	dest.EnabledPresets = make([]string, len(source.EnabledPresets))
	copy(dest.EnabledPresets, source.EnabledPresets)
	dest.PresetOverrides = make(map[string]string)
	for k, v := range source.PresetOverrides {
		dest.PresetOverrides[k] = v
	}

	m.saveProfiles()
	m.message = "Copied presets from " + source.DisplayName
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
		{"Key Tester (t)", "t"},
		{"Apply (a)", "a"},
		{"Fn Row Mode:", "f"},
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
				if m.fnmodeAvailable {
					m.selectedPresetIdx++
				}
				m.focusArea = 1
				if preset.Type == "remap" {
					// Trailing remap target sits after the label; click past the
					// label opens the key picker.
					labelEnd := idx + len(rowText)
					if clickX >= labelEnd {
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

func (m Model) heroTone() ui.Tone {
	if m.status == nil {
		return ui.ToneIdle
	}
	if m.status.Bool("keydRunning") {
		return ui.ToneOK
	}
	return ui.ToneDanger
}

func (m Model) selectedPresetCount() int {
	if m.selectedDeviceIdx >= len(m.devices) {
		return 0
	}
	_, prof := m.profileForDevice(m.devices[m.selectedDeviceIdx])
	if prof == nil || !prof.Enabled {
		return 0
	}
	return len(prof.EnabledPresets)
}

func (m Model) onlineCount() int {
	n := 0
	for _, d := range m.devices {
		if d.Connected {
			n++
		}
	}
	return n
}

func (m Model) heroSubtitle() string {
	keyd := "keyd inactive"
	if m.status != nil && m.status.Bool("keydRunning") {
		keyd = "keyd active"
	}
	parts := []string{
		keyd,
		fmt.Sprintf("%d devices", len(m.devices)),
		fmt.Sprintf("%d presets on", m.selectedPresetCount()),
	}
	if m.status != nil && m.status.Bool("pendingChanges") {
		parts = append(parts, "pending")
	}
	return strings.Join(parts, " · ")
}

func (m Model) helpItems() []string {
	return []string{
		ui.HelpItem("arrows", "navigate"),
		ui.HelpItem("tab", "column"),
		ui.HelpItem("space", "toggle"),
		ui.HelpItem("enter", "edit key"),
		ui.HelpItem("a", "apply"),
		ui.HelpItem("s", "setup"),
		ui.HelpItem("t", "tester"),
		ui.HelpItem("pgup/pgdn", "logs"),
		ui.HelpItem("r", "refresh"),
		ui.HelpItem("q", "quit"),
	}
}

func (m Model) View() string {
	if m.width <= 0 || m.height <= 0 {
		return "Initializing..."
	}

	if m.showPicker {
		pickerView := m.renderPickerView()
		return lipgloss.Place(m.width, m.height, lipgloss.Center, lipgloss.Center, pickerView)
	}

	msg := ""
	if m.message != "" && !m.busy {
		msg = m.message
	}
	hero := ui.Hero("Keyboard Remap", m.heroSubtitle(), ui.HeroOpts{
		Tone:    m.heroTone(),
		Busy:    m.busy,
		Message: msg,
	})

	help := m.helpItems()
	pending := ""
	if m.status != nil && m.status.Bool("pendingChanges") {
		pending = ui.PendingLine("a", "r")
	}

	const (
		screenPaddingX = 2
		screenPaddingY = 2
		columnGap      = 2
	)
	contentW := m.width - screenPaddingX
	if contentW < 40 {
		contentW = 40
	}
	leftW := min(54, max(28, contentW/3))
	rightW := contentW - leftW - columnGap
	if rightW < 30 {
		rightW = 30
		leftW = max(24, contentW-columnGap-rightW)
	}
	heroH := strings.Count(hero, "\n") + 1
	fixedRows := heroH
	if len(help) > 0 {
		fixedRows++
	}
	if pending != "" {
		fixedRows++
	}
	contentH := m.height - screenPaddingY - fixedRows
	if contentH < 12 {
		contentH = 12
	}

	return ui.RenderPage(ui.Page{
		Width:   m.width,
		Height:  m.height,
		Hero:    hero,
		Left:    m.renderLeftColumn(leftW),
		Right:   m.renderRightColumn(rightW, contentH),
		Wide:    m.width >= 90,
		Help:    help,
		Pending: pending,
	})
}

func (m Model) renderPickerView() string {
	var b strings.Builder

	b.WriteString(ui.OKText.Bold(true).Render("Select Target Key Override"))
	b.WriteString("\n\n")

	for rowIdx, row := range keyboardRows {
		b.WriteString("  ")
		for colIdx, key := range row {
			isSel := m.pickerRow == rowIdx && m.pickerCol == colIdx
			b.WriteString(renderKey(key, isSel))
		}
		b.WriteString("\n")
	}

	b.WriteString("\n")
	b.WriteString(ui.MutedText.Render("  arrows: navigate  |  Enter/Space: select  |  Esc: cancel"))
	b.WriteString("\n")

	return lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(ui.Line).
		Background(ui.Panel).
		Padding(1, 2).
		Render(ui.PreserveBackground(b.String(), ui.Panel))
}

func (m Model) renderLeftColumn(width int) string {
	var b strings.Builder

	online := m.onlineCount()
	offline := len(m.devices) - online
	b.WriteString(ui.SectionTitle("Keyboards"))
	b.WriteString(" ")
	b.WriteString(ui.SubtleText.Render(fmt.Sprintf("%d online · %d offline", online, offline)))
	b.WriteString("\n")

	for i, dev := range m.devices {
		// Name + online/offline tag right-aligned when width allows.
		name := dev.DisplayName
		tag := "offline"
		if dev.Connected {
			tag = "online"
		}
		row := ui.ListItem(name, ui.ListItemOpts{
			Focused:   m.focusArea == 0 && i == m.selectedDeviceIdx,
			Connected: dev.Connected,
			Offline:   false, // tag rendered separately for alignment
		})
		// Strip default offline suffix; we print tag on the right.
		plainName := name
		tagStyled := ui.SubtleText.Render(tag)
		if dev.Connected {
			tagStyled = ui.OKText.Render(tag)
		}
		used := lipgloss.Width(ui.TruncatePlain(stripForWidth(row), width))
		// Simpler: build row manually for alignment.
		bullet := "○"
		labelStyle := lipgloss.NewStyle().Foreground(ui.Subtle)
		if dev.Connected {
			bullet = "●"
			labelStyle = lipgloss.NewStyle().Foreground(ui.Text)
		}
		if m.focusArea == 0 && i == m.selectedDeviceIdx {
			bullet = "▸"
			labelStyle = lipgloss.NewStyle().Foreground(ui.Accent).Bold(true)
		}
		left := bullet + " " + labelStyle.Render(ui.TruncatePlain(plainName, max(4, width-10)))
		gap := width - lipgloss.Width(left) - lipgloss.Width(tag)
		if gap < 1 {
			gap = 1
		}
		b.WriteString(left + strings.Repeat(" ", gap) + tagStyled)
		b.WriteString("\n")
		_ = used
	}

	b.WriteString("\n")
	b.WriteString(ui.SectionTitle("Health"))
	b.WriteString("\n")
	b.WriteString(m.healthLines(width))
	b.WriteString("\n")
	b.WriteString(ui.SectionTitle("Actions"))
	b.WriteString("\n")
	b.WriteString(ui.ActionLine("s", "Setup keyd", !m.busy))
	b.WriteString("\n")
	b.WriteString(ui.ActionLine("t", "Key Tester", !m.busy))
	b.WriteString("\n")
	b.WriteString(ui.ActionLine("a", "Apply remaps", !m.busy && m.status != nil && m.status.Bool("pendingChanges")))
	b.WriteString("\n")
	b.WriteString(ui.ActionLine("r", "Refresh", !m.busy))
	b.WriteString("\n")

	return b.String()
}

func stripForWidth(s string) string {
	return s
}

func (m Model) healthLines(width int) string {
	keyd := "inactive"
	keydTone := ui.ToneDanger
	if m.status != nil && m.status.Bool("keydRunning") {
		keyd = "active"
		keydTone = ui.ToneOK
	} else if m.status != nil && m.status.Bool("keydInstalled") {
		keyd = "installed"
		keydTone = ui.ToneWarn
	}

	conf := "omd.conf"
	apply := "—"
	if m.lastApplyOK != nil {
		if *m.lastApplyOK {
			apply = "ok"
		} else {
			apply = "error"
		}
	} else if m.status != nil && m.status.Bool("pendingChanges") {
		apply = "pending"
	}

	lines := []string{
		ui.KVLine("keyd", ui.StatusDot(keydTone)+" "+keyd, width),
		ui.KVLine("conf", conf, width),
		ui.KVLine("apply", apply, width),
	}
	if m.status != nil && m.status.Bool("pendingChanges") {
		lines = append(lines, ui.WarnText.Render("draft differs from installed"))
	}
	return strings.Join(lines, "\n")
}

func (m Model) renderRightColumn(width, contentH int) string {
	if m.selectedDeviceIdx >= len(m.devices) {
		return ui.MutedText.Render("Select a keyboard device to configure…")
	}

	dev := m.devices[m.selectedDeviceIdx]
	_, prof := m.profileForDevice(dev)
	exists := prof != nil
	isEnabled := exists && prof.Enabled

	var parts []string

	title := "Profile"
	if dev.DisplayName != "" {
		title = "Profile · " + ui.TruncatePlain(dev.DisplayName, max(8, width-12))
	}
	parts = append(parts, ui.SectionTitle(title))
	parts = append(parts, ui.KVLine("Device", dev.DisplayName, width))
	id := dev.KeydID
	if id == "" {
		id = "—"
	}
	parts = append(parts, ui.KVLine("ID", id, width))
	parts = append(parts, ui.ProfileEnabledLine(isEnabled, m.focusArea == 1 && m.selectedPresetIdx == 0))

	if m.fnmodeAvailable {
		parts = append(parts, "")
		parts = append(parts, ui.SectionTitle("Function Row"))
		parts = append(parts, ui.CycleLine("Fn Row Mode", m.fnmode, "f", m.focusArea == 1 && m.selectedPresetIdx == 1))
	}

	onCount := 0
	if isEnabled && exists {
		onCount = len(prof.EnabledPresets)
	}
	parts = append(parts, "")
	parts = append(parts, ui.SectionTitle("Presets")+" "+ui.SubtleText.Render(fmt.Sprintf("%d on", onCount)))

	for i, preset := range globalPresetChoices {
		active := false
		if isEnabled && exists {
			for _, pid := range prof.EnabledPresets {
				if pid == preset.ID {
					active = true
					break
				}
			}
		}

		presetRow := i + 1
		if m.fnmodeAvailable {
			presetRow++
		}
		focused := m.focusArea == 1 && m.selectedPresetIdx == presetRow

		trailing := ""
		if preset.Type == "remap" {
			target := preset.DefaultTo
			if exists && prof.PresetOverrides != nil {
				if val, ok := prof.PresetOverrides[preset.ID]; ok && val != "" {
					target = val
				}
			}
			trailing = target
		}

		parts = append(parts, m.presetRow(width, active, preset.Label, trailing, focused, !isEnabled))
	}

	mainContent := strings.Join(parts, "\n")
	mainH := strings.Count(mainContent, "\n") + 1

	logH := contentH - mainH - 2
	if logH < 3 {
		logH = 3
	}

	return mainContent + "\n\n" + ui.SectionTitle("Activity") + "\n" + m.renderLogBody(width, logH)
}

// presetRow draws "[X] label … trailing" with trailing right-aligned.
func (m Model) presetRow(width int, on bool, label, trailing string, focused, dimmed bool) string {
	box := "[ ]"
	if on {
		box = "[X]"
	}
	style := lipgloss.NewStyle().Foreground(ui.Text)
	trailStyle := lipgloss.NewStyle().Foreground(ui.Accent)
	if dimmed {
		style = lipgloss.NewStyle().Foreground(ui.Subtle)
		trailStyle = lipgloss.NewStyle().Foreground(ui.Subtle)
	} else if focused {
		style = lipgloss.NewStyle().Foreground(ui.Accent).Bold(true)
	}

	left := box + " " + style.Render(ui.TruncatePlain(label, max(6, width-12)))
	if trailing == "" {
		return left
	}
	trail := trailStyle.Render(trailing)
	gap := width - lipgloss.Width(left) - lipgloss.Width(trail)
	if gap < 1 {
		// Truncate label further.
		maxLabel := max(4, width-lipgloss.Width(box)-1-lipgloss.Width(trail)-1)
		left = box + " " + style.Render(ui.TruncatePlain(label, maxLabel))
		gap = width - lipgloss.Width(left) - lipgloss.Width(trail)
		if gap < 1 {
			gap = 1
		}
	}
	return left + strings.Repeat(" ", gap) + trail
}

func (m Model) renderLogBody(width, height int) string {
	if height <= 0 {
		return ""
	}
	logWidth := width - 2 // scrollbar column
	if logWidth < 8 {
		logWidth = 8
	}

	var wrapped []string
	if len(m.logs) == 0 {
		wrapped = []string{ui.SubtleText.Render("No activity yet.")}
	} else {
		for _, line := range m.logs {
			for _, w := range ui.WrapStyled(line, logWidth) {
				wrapped = append(wrapped, w)
			}
		}
	}

	total := len(wrapped)
	out := make([]string, height)
	if total == 0 {
		for i := 0; i < height; i++ {
			out[i] = strings.Repeat(" ", logWidth) + " " + ui.SubtleText.Render("│")
		}
		return strings.Join(out, "\n")
	}

	if total <= height {
		for i := 0; i < height; i++ {
			if i < total {
				out[i] = ui.PadPlain(wrapped[i], logWidth) + " " + ui.SubtleText.Render("│")
			} else {
				out[i] = strings.Repeat(" ", logWidth) + " " + ui.SubtleText.Render("│")
			}
		}
		return strings.Join(out, "\n")
	}

	maxOff := total - height
	off := m.scrollOffset
	if off > maxOff {
		off = maxOff
	}
	if off < 0 {
		off = 0
	}
	start := total - height - off
	end := start + height
	thumbStart := (start * height) / total
	thumbEnd := (end * height) / total
	if thumbEnd-thumbStart < 1 {
		thumbEnd = thumbStart + 1
	}
	if thumbEnd > height {
		thumbEnd = height
	}
	for i := 0; i < height; i++ {
		sb := ui.SubtleText.Render("│")
		if i >= thumbStart && i < thumbEnd {
			sb = ui.OKText.Render("┃")
		}
		out[i] = ui.PadPlain(wrapped[start+i], logWidth) + " " + sb
	}
	return strings.Join(out, "\n")
}

func renderKey(k Key, isSelected bool) string {
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
			Foreground(ui.Background).
			Background(ui.Accent).
			Bold(true).
			Render("[" + padded + "]")
	}
	return lipgloss.NewStyle().
		Foreground(ui.Text).
		Render("[" + padded + "]")
}
