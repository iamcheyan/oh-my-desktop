package theme

import (
	"strings"
	"testing"

	"github.com/charmbracelet/lipgloss"

	"github.com/iamcheyan/oh-my-desktop/tui-go/internal/backend"
)

func TestRightColumnFitsViewport(t *testing.T) {
	m := Model{status: backend.Status{
		"wallpaper.mode":       "folder",
		"wallpaper.current":    "/home/test/Pictures/wallpapers/a-very-long-wallpaper-file-name.png",
		"wallpaper.imageCount": "42",
		"wallpaper.interval":   "3600",
		"effects.mode":         "balanced",
	}}
	m.width, m.height = 120, 40

	view := m.rightColumn()
	for row, line := range strings.Split(view, "\n") {
		if got := lipgloss.Width(line); got > 80 {
			t.Fatalf("row %d rendered as %d columns (too wide for right pane)", row, got)
		}
	}
}

func TestWallpaperControlsFollowMode(t *testing.T) {
	m := Model{status: backend.Status{
		"wallpaper.mode":       "file",
		"wallpaper.current":    "/tmp/wallpaper.png",
		"wallpaper.imageCount": "12",
		"wallpaper.interval":   "3600",
		"effects.mode":         "visuals",
	}}

	fileView := m.wallpaperControls(100)
	if !strings.Contains(fileView, "Settings & Status") || !strings.Contains(fileView, "vis (3)") {
		t.Fatal("file mode is missing settings and status or effects")
	}

	m.status["wallpaper.mode"] = "folder"
	folderView := m.wallpaperControls(100)
	if !strings.Contains(folderView, "rotating every 1h") {
		t.Fatal("folder mode is missing rotation info")
	}

	m.status["wallpaper.mode"] = "color"
	colorView := m.wallpaperControls(100)
	if !strings.Contains(colorView, "Active Background") || !strings.Contains(colorView, "Solid color") {
		t.Fatal("color mode is missing active background info")
	}
}

func TestThemePageUsesSharedShell(t *testing.T) {
	m := Model{
		status: backend.Status{
			"wallpaper.mode": "file",
			"theme.current":  "last-horizon",
			"effects.mode":   "balanced",
		},
		themes: []themeEntry{{slug: "last-horizon", name: "Last Horizon", current: true}},
		width:  120,
		height: 40,
	}
	out := m.View()
	for _, s := range []string{"Theme & Appearance", "Themes", "Settings & Status"} {
		if !strings.Contains(out, s) {
			t.Fatalf("theme page missing %q\n%s", s, out)
		}
	}
}
