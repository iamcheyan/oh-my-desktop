package voice

import (
	"strings"
	"testing"
	"time"

	"github.com/charmbracelet/lipgloss"
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
		"state":          "idle",
		"modelReady":     "true",
		"venvReady":      "true",
		"modelSizeMB":    "229",
		"daemonRunning":  "false",
		"recent":         "[]",
		"bindingsFile":   "/tmp/voice_bindings.txt",
		"defaultTrigger": "ALT + A",
	})
	// inject binding lines via Raw parse — Status.Raw may not include bindings;
	// set bindings directly.
	m.bindings = []string{"ALT + A", "XF86Tools"}

	out := m.View()
	for _, s := range []string{"VOICE TRIGGERS", "trial record", "Alt + A", "F13 / Tools", "MODEL SPECIFICATIONS", "Delete model"} {
		if !strings.Contains(out, s) {
			t.Errorf("ready view missing %q\n%s", s, out)
		}
	}
	if strings.Contains(out, "GET STARTED") {
		t.Error("ready view should not show setup guide")
	}
}

func TestReadyViewFitsHeightAndDeduplicatesFriendlyBindings(t *testing.T) {
	m := modelWithStatus(backend.Status{
		"state":         "idle",
		"modelReady":    "true",
		"venvReady":     "true",
		"modelSizeMB":   "229",
		"daemonRunning": "false",
		"recent":        "[]",
	})
	m.bindings = []string{"ALT + A", "0X100811D0", "HANGUL_HANJA", "XF86Tools"}

	out := m.View()
	if got := lipgloss.Height(out); got != m.height {
		t.Fatalf("view height = %d, want %d", got, m.height)
	}
	if got := strings.Count(out, "Hangul / Hanja"); got != 1 {
		t.Fatalf("Hangul / Hanja count = %d, want 1", got)
	}
}

func TestTrialLogsInsteadOfModal(t *testing.T) {
	m := modelWithStatus(backend.Status{
		"state":       "idle",
		"modelReady":  "true",
		"venvReady":   "true",
		"modelSizeMB": "229",
		"recent":      "[]",
		"micLevel":    "0",
	})

	// Starting a trial must not open a modal; it should write to logs.
	updated, _ := m.startTrial()
	m = updated.(Model)
	if !m.trialListening {
		t.Fatal("expected trialListening after startTrial")
	}
	joined := strings.Join(m.logs, "\n")
	for _, s := range []string{
		"VOICE TRIAL",
		"Please speak into your microphone",
		"Space = stop & transcribe",
		"Esc   = cancel",
	} {
		if !strings.Contains(joined, s) {
			t.Errorf("trial logs missing %q\n%s", s, joined)
		}
	}

	// View must not show the old modal chrome.
	out := m.View()
	if strings.Contains(out, "Voice trial") {
		t.Error("modal title should not appear after removing the popup")
	}

	// Live progress should land in logs.
	m.status["micLevel"] = "40"
	m.status["state"] = "recording"
	m.recStart = time.Now().Add(-2 * time.Second)
	m.logTrialProgress()
	joined = strings.Join(m.logs, "\n")
	if !strings.Contains(joined, "Speech detected") {
		t.Errorf("expected speech-detected log line\n%s", joined)
	}
	if !strings.Contains(joined, "level=40") {
		t.Errorf("expected level in logs\n%s", joined)
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
