package theme

import (
	"strings"
	"testing"

	"github.com/charmbracelet/lipgloss"

	"github.com/iamcheyan/oh-my-desktop/tui-go/internal/backend"
)

func TestHeroViewFitsViewport(t *testing.T) {
	m := Model{status: backend.Status{
		"wallpaper.mode":       "folder",
		"wallpaper.current":    "/home/test/Pictures/wallpapers/a-very-long-wallpaper-file-name.png",
		"wallpaper.imageCount": "42",
		"wallpaper.interval":   "3600",
		"effects.mode":         "balanced",
	}}

	for _, width := range []int{54, 80, 120, 160} {
		view := m.heroView(width)
		for row, line := range strings.Split(view, "\n") {
			if got := lipgloss.Width(line); got > width {
				t.Fatalf("width %d row %d rendered as %d columns", width, row, got)
			}
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
	if !strings.Contains(fileView, "SETTINGS & STATUS") || !strings.Contains(fileView, "Vis (3)") {
		t.Fatal("file mode is missing settings and status or effects")
	}

	m.status["wallpaper.mode"] = "folder"
	folderView := m.wallpaperControls(100)
	if !strings.Contains(folderView, "rotating every 1h") {
		t.Fatal("folder mode is missing rotation info")
	}
}
