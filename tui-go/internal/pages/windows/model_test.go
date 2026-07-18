package windows

import (
	"os"
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"github.com/iamcheyan/oh-my-desktop/tui-go/internal/backend"
	"github.com/iamcheyan/oh-my-desktop/tui-go/internal/ui"
)

func execute(cmd tea.Cmd) (tea.Msg, error) {
	if cmd == nil {
		return nil, nil
	}
	return cmd(), nil
}

func modelWithStatus(status backend.Status) Model {
	m := New(backend.New(""))
	m.status = status
	m.width = 100
	m.height = 32
	return m
}

func TestBlockedViewGuidesFixNotManage(t *testing.T) {
	m := modelWithStatus(backend.Status{
		"configured":        "false",
		"phase":             "not-installed",
		"container":         "missing",
		"kvm":               "true",
		"dockerCli":         "true",
		"dockerDaemon":      "false",
		"dockerAccess":      "false",
		"dockerGroupMember": "false",
		"dockerError":       "permission denied while trying to connect to the docker API",
		"compose":           "true",
		"freerdp":           "true",
		"freerdpBin":        "xfreerdp",
		"diskAvailable":     "49",
		"ready":             "false",
		"webReachable":      "false",
		"rdpReachable":      "false",
		"web":               "http://127.0.0.1:8006",
		"rdpEndpoint":       "127.0.0.1:3389",
		"sharedDir":         "/home/t/Windows",
	})

	if m.primaryState() != "blocked" {
		t.Fatalf("primaryState=%q want blocked", m.primaryState())
	}
	if m.showSidePanel() {
		t.Fatal("blocked (idle) should not show side panel/logs")
	}

	out := m.View()
	want := []string{
		"WHAT'S BLOCKING",
		"Docker access",
		"permission denied",
		"Free disk space",
		"Fix requirements",
		"NEXT STEP",
	}
	for _, s := range want {
		if !strings.Contains(out, s) {
			t.Errorf("blocked view missing %q\n%s", s, out)
		}
	}
	// Manage/connect noise should stay hidden until a VM exists.
	for _, s := range []string{"CONNECTION", "SPECS", "Open web console", "Stop VM", "Remove VM", "StatusPill", "Docker]", "[KVM"} {
		if strings.Contains(out, s) {
			t.Errorf("blocked view should not contain %q", s)
		}
	}
}

func TestInstallViewGuidesInstallHidesLogs(t *testing.T) {
	m := modelWithStatus(backend.Status{
		"configured":    "false",
		"phase":         "not-installed",
		"container":     "missing",
		"kvm":           "true",
		"dockerCli":     "true",
		"dockerDaemon":  "true",
		"dockerAccess":  "true",
		"compose":       "true",
		"freerdp":       "true",
		"diskAvailable": "120",
		"ready":         "false",
		"web":           "http://127.0.0.1:8006",
		"rdpEndpoint":   "127.0.0.1:3389",
		"sharedDir":     "/home/t/Windows",
	})

	if m.primaryState() != "install" {
		t.Fatalf("primaryState=%q want install", m.primaryState())
	}
	if m.showSidePanel() {
		t.Fatal("install (idle) should not show side panel/logs")
	}

	out := m.View()
	for _, s := range []string{"GET STARTED", "Install Windows", "DEFAULTS", "Shared folder", "NEXT STEP"} {
		if !strings.Contains(out, s) {
			t.Errorf("install view missing %q\n%s", s, out)
		}
	}
	for _, s := range []string{"WHAT'S BLOCKING", "Stop VM", "Remove VM", "Open web console"} {
		if strings.Contains(out, s) {
			t.Errorf("install view should not contain %q", s)
		}
	}
}

func TestReadyViewShowsConnectAndDanger(t *testing.T) {
	m := modelWithStatus(backend.Status{
		"configured":   "true",
		"phase":        "ready",
		"container":    "running",
		"kvm":          "true",
		"dockerCli":    "true",
		"dockerAccess": "true",
		"compose":      "true",
		"freerdp":      "true",
		"diskAvailable": "120",
		"ready":        "true",
		"webReachable": "true",
		"rdpReachable": "true",
		"web":          "http://127.0.0.1:8006",
		"rdpEndpoint":  "127.0.0.1:3389",
		"storageDir":   "/home/t/.windows",
	})

	if m.primaryState() != "ready" {
		t.Fatalf("primaryState=%q want ready", m.primaryState())
	}
	if !m.showSidePanel() {
		t.Fatal("ready should show side panel")
	}

	out := m.View()
	for _, s := range []string{"Connect", "Open web console", "Stop VM", "Remove VM", "CONNECTION"} {
		if !strings.Contains(out, s) {
			t.Errorf("ready view missing %q\n%s", s, out)
		}
	}
}

func TestViewFitsTerminalHeight(t *testing.T) {
	root := os.Getenv("OMD_ROOT")
	if root == "" {
		root = "/home/tetsuya/development/OMD"
	}
	b := backend.New(root)
	m := New(b)
	statusCmd := m.fetchStatus()
	if msg, err := execute(statusCmd); err == nil && msg != nil {
		mm, _ := m.Update(msg)
		m = mm.(Model)
	}
	logsCmd := m.fetchLogs()
	if msg, err := execute(logsCmd); err == nil && msg != nil {
		mm, _ := m.Update(msg)
		m = mm.(Model)
	}
	m.logs = append(m.logs, "$ connect", "connected", "ok")
	m.logs = ui.ClipLines(m.logs, 140)

	for _, wh := range [][2]int{{120, 24}, {120, 28}, {120, 30}, {120, 36}, {120, 40}, {120, 50}, {120, 80}} {
		mm, _ := m.Update(tea.WindowSizeMsg{Width: wh[0], Height: wh[1]})
		out := mm.View()
		h := lipgloss.Height(out)
		t.Logf("rows=%d cols=%d  rendered_height=%d  ok=%v", wh[1], wh[0], h, h <= wh[1])
		if h > wh[1] || os.Getenv("DUMP_VIEW") != "" {
			lines := strings.Split(out, "\n")
			for i, l := range lines {
				t.Logf("%2d| %s", i, l)
			}
		}
		if h > wh[1] {
			t.Errorf("rows=%d: rendered height %d exceeds terminal %d", wh[1], h, wh[1])
		}
	}
}
