package ui

import (
	"fmt"
	"strings"
)

// ShortPath collapses a long filesystem path to its last two segments,
// prefixed with "…/". Short paths (≤3 segments) are returned as-is. The
// "/tmp/" prefix is preserved because those paths are already short and
// leaving them absolute makes them greppable. Empty input returns "-".
func ShortPath(p string) string {
	p = strings.TrimSpace(p)
	if p == "" {
		return "-"
	}
	if strings.HasPrefix(p, "/tmp/") {
		return p
	}
	parts := strings.Split(p, "/")
	if len(parts) <= 3 {
		return p
	}
	return "…/" + strings.Join(parts[len(parts)-2:], "/")
}

// ParseInt parses a decimal integer from raw, returning 0 on any error.
// TrimSpace is applied first so callers can pass status values directly.
func ParseInt(raw string) int {
	var n int
	_, _ = fmt.Sscanf(strings.TrimSpace(raw), "%d", &n)
	return n
}

// ProgressBar renders a filled/empty bar of width columns using block
// glyphs. percent is clamped to [0,100]. The filled portion uses the accent
// color, the empty portion uses the subtle color.
func ProgressBar(percent, width int) string {
	width = max(4, width)
	percent = max(0, min(100, percent))
	filled := percent * width / 100
	return OKText.Render(strings.Repeat("█", filled)) +
		SubtleText.Render(strings.Repeat("░", width-filled))
}

// FormatDuration renders seconds as MM:SS.
func FormatDuration(sec int) string {
	return fmt.Sprintf("%02d:%02d", sec/60, sec%60)
}