package keyboard

import (
	"strings"
	"testing"

	"github.com/iamcheyan/oh-my-desktop/tui-go/internal/backend"
)

func TestKeyboardPage(t *testing.T) {
	m := Model{
		devices: []Device{
			{HyprName: "minila-r-convertible", DisplayName: "minila-r-convertible", Connected: true},
		},
		selectedDeviceIdx: 0,
		focusArea:         0,
		selectedPresetIdx: 0,
		status: backend.Status{
			"keydRunning": "true",
		},
	}

	m.profiles = Profiles{
		Version: 1,
		Devices: map[string]*Profile{
			"minila-r-convertible": {
				DisplayName:     "minila-r-convertible",
				HyprName:        "minila-r-convertible",
				Enabled:         true,
				EnabledPresets:  []string{"alt-win-swap"},
				PresetOverrides: make(map[string]string),
			},
		},
	}

	// 1. Assert simple rendering (series shell + Title Case sections)
	m.width, m.height = 120, 40
	view := m.View()
	if !strings.Contains(view, "Connected Keyboards") || !strings.Contains(view, "minila-r-convertible") {
		t.Fatal("keyboard view is missing device list or section headers")
	}
	if !strings.Contains(view, "Keyboard Remap") {
		t.Fatal("keyboard view is missing shared hero title")
	}

	// 2. Toggle Profile Enabled
	m.toggleSelectedProfileEnabled()
	prof := m.profiles.Devices["minila-r-convertible"]
	if prof.Enabled {
		t.Fatal("profile enabled state was not toggled to false")
	}

	// 3. Toggle Presets
	m.focusArea = 1
	m.selectedPresetIdx = 1 // alt-win-swap
	m.toggleSelectedPreset()
	// Since "alt-win-swap" was already active, toggling it should remove it
	found := false
	for _, id := range prof.EnabledPresets {
		if id == "alt-win-swap" {
			found = true
			break
		}
	}
	if found {
		t.Fatal("alt-win-swap preset was not disabled by toggle")
	}
}

func TestKeyboardPicker(t *testing.T) {
	m := Model{
		devices: []Device{
			{HyprName: "minila-r-convertible", DisplayName: "minila-r-convertible", Connected: true},
		},
		selectedDeviceIdx: 0,
		focusArea:         1,
		selectedPresetIdx: 5, // muhenkan-meta
		showPicker:        false,
	}

	m.profiles = Profiles{
		Version: 1,
		Devices: map[string]*Profile{
			"minila-r-convertible": {
				DisplayName:     "minila-r-convertible",
				HyprName:        "minila-r-convertible",
				Enabled:         true,
				EnabledPresets:  []string{},
				PresetOverrides: make(map[string]string),
			},
		},
	}

	m.triggerOverridePicker()
	if !m.showPicker || m.pickerPresetID != "muhenkan-meta" {
		t.Fatal("failed to open picker modal for muhenkan-meta")
	}

	// Move cursor inside visual keyboard picker
	m.pickerRow = 6 // Extended F-keys row
	m.pickerCol = 0 // F13 key
	m.confirmPickerSelection()

	prof := m.profiles.Devices["minila-r-convertible"]
	if prof.PresetOverrides["muhenkan-meta"] != "f13" {
		t.Fatal("muhenkan-meta target was not overridden to f13")
	}
	if m.showPicker {
		t.Fatal("picker modal did not close after confirming selection")
	}
}

func TestConnectedKeyboardUsesConfiguredAliasProfile(t *testing.T) {
	m := Model{
		profiles: Profiles{
			Version: 1,
			Devices: map[string]*Profile{
				"minila-r-convertible": {
					HyprName:       "minila-r-convertible",
					Enabled:        true,
					EnabledPresets: []string{"alt-win-swap", "grave-esc-swap"},
				},
			},
		},
	}
	connected := Device{
		HyprName:    "minila-r-convertible-keyboard",
		DisplayName: "MINILA-R Convertible Keyboard",
		KeydID:      "0a5c:8502",
	}

	m.mergeDevices([]Device{connected})
	if len(m.devices) != 1 {
		t.Fatalf("expected one logical keyboard, got %d", len(m.devices))
	}
	_, profile := m.profileForDevice(connected)
	if profile == nil || len(profile.EnabledPresets) != 2 {
		t.Fatal("connected alias did not resolve to the configured profile")
	}
}

func TestFnModeRendersOnlyInRightColumn(t *testing.T) {
	m := Model{
		devices: []Device{{HyprName: "apple-spi-keyboard", DisplayName: "Apple SPI Keyboard"}},
		profiles: Profiles{Version: 1, Devices: map[string]*Profile{
			"apple-spi-keyboard": {HyprName: "apple-spi-keyboard", Enabled: true},
		}},
		fnmodeAvailable: true,
		fnmode:          "media",
	}

	if strings.Contains(m.renderLeftColumn(), "Fn Row Mode") {
		t.Fatal("Fn mode control should not render in the keyboard list")
	}
	if !strings.Contains(m.renderRightColumn(), "Fn Row Mode") {
		t.Fatal("Fn mode control is missing from the detail column")
	}
}
