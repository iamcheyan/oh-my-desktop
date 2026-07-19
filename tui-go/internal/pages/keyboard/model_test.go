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

	// 1. Assert simple rendering
	view := m.View()
	if !strings.Contains(view, "CONNECTED KEYBOARDS") || !strings.Contains(view, "minila-r-convertible") {
		t.Fatal("keyboard view is missing device list or section headers")
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
