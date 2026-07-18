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

func TestViewFitsTerminalHeight(t *testing.T) {
	root := os.Getenv("OMD_ROOT")
	if root == "" {
		root = "/home/tetsuya/Development/oh-my-desktop"
	}
	b := backend.New(root)
	m := New(b)
	// drive one status + logs fetch so we have real content
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
	// fake some action log lines to grow logs
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
