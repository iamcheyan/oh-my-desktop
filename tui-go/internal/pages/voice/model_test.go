package voice

import (
	"strings"
	"testing"

	"github.com/iamcheyan/oh-my-desktop/tui-go/internal/backend"
)

func modelWithStatus(status backend.Status) Model {
	m := New(backend.New(""))
	m.status = status
	m.width = 100
	m.height = 32
	m.bindings = parseBindings(status.Raw())
	return m
}

func TestSetupViewHidesDayToDaySettings(t *testing.T) {
	m := modelWithStatus(backend.Status{
		"state":         "nomodel",
		"modelReady":    "false",
		"venvReady":     "false",
		"modelSizeMB":   "0",
		"daemonRunning": "false",
		"recent":        "[]",
	})

	out := m.View()
	for _, s := range []string{"GET STARTED", "Setup voice input", "SenseVoice model", "Python virtual environment"} {
		if !strings.Contains(out, s) {
			t.Errorf("setup view missing %q\n%s", s, out)
		}
	}
	for _, s := range []string{"TRIAL RECORD", "BINDINGS", "RECENT", "Record (enter)"} {
		if strings.Contains(out, s) {
			t.Errorf("setup view should not show day-to-day %q", s)
		}
	}
}

func TestReadyViewShowsSettings(t *testing.T) {
	m := modelWithStatus(backend.Status{
		"state":         "idle",
		"modelReady":    "true",
		"venvReady":     "true",
		"modelSizeMB":   "229",
		"daemonRunning": "false",
		"recent":        "[]",
		"bindingsFile":  "/tmp/voice_bindings.txt",
		"defaultTrigger": "ALT + A",
	})
	// inject binding lines via Raw parse — Status.Raw may not include bindings;
	// set bindings directly.
	m.bindings = []string{"ALT + A", "XF86Tools"}

	out := m.View()
	for _, s := range []string{"TRIAL RECORD", "Record", "BINDINGS", "Alt + A", "ADVANCED"} {
		if !strings.Contains(out, s) {
			t.Errorf("ready view missing %q\n%s", s, out)
		}
	}
	if strings.Contains(out, "GET STARTED") {
		t.Error("ready view should not show setup guide")
	}
}

func TestDownloadingViewShowsProgress(t *testing.T) {
	m := modelWithStatus(backend.Status{
		"state":             "downloading",
		"modelReady":        "false",
		"venvReady":         "true",
		"download.percent":  "42",
		"download.label":    "SenseVoice",
		"download.speedBps": "1048576",
		"download.etaSec":   "120",
	})

	out := m.View()
	for _, s := range []string{"PROGRESS", "Downloading", "Cancel setup", "42%"} {
		if !strings.Contains(out, s) {
			t.Errorf("downloading view missing %q\n%s", s, out)
		}
	}
	if strings.Contains(out, "BINDINGS") {
		t.Error("downloading view should not show bindings")
	}
}
