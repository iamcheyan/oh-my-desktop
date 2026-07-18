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
		"wallpaper.interval":   "1800",
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
		"wallpaper.interval":   "1800",
		"effects.mode":         "visuals",
	}}

	fileView := m.wallpaperControls(100, "file")
	for _, hidden := range []string{"Current", "Images", "Interval", "Next", "Stop"} {
		if strings.Contains(fileView, hidden) {
			t.Fatalf("file mode unexpectedly contains %q", hidden)
		}
	}
	if !strings.Contains(fileView, "Effects") || !strings.Contains(fileView, "Visuals") {
		t.Fatal("file mode is missing compact effects selector")
	}

	folderView := m.wallpaperControls(100, "folder")
	for _, visible := range []string{"Interval", "Next", "Stop", "30m"} {
		if !strings.Contains(folderView, visible) {
			t.Fatalf("folder mode is missing %q", visible)
		}
	}
}
