package ui

import (
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// HexColor converts a "#rrggbb" (or "rrggbb") string into a lipgloss.Color.
// Returns nil when the input is not a valid 6-digit hex value so callers can
// fall back to a default style.
func HexColor(hex string) lipgloss.Color {
	hex = strings.TrimSpace(hex)
	hex = strings.TrimPrefix(hex, "#")
	if len(hex) != 6 {
		return ""
	}
	for _, c := range hex {
		switch {
		case c >= '0' && c <= '9':
		case c >= 'a' && c <= 'f':
		case c >= 'A' && c <= 'F':
		default:
			return ""
		}
	}
	return lipgloss.Color("#" + hex)
}

// ColorSwatch renders a text-on-background sample ("Ag" in fg over bg) on the
// left half, and a solid accent block on the right half. Width controls the
// total visible columns (clamped to at least 4). When a color is empty the
// corresponding block falls back to the panel background so the swatch still
// occupies the requested width.
func ColorSwatch(bg, fg, accent lipgloss.Color, width int) string {
	if width < 4 {
		width = 4
	}
	half := width / 2
	rest := width - half

	if bg == "" {
		bg = Panel
	}
	if fg == "" {
		fg = Text
	}
	if accent == "" {
		accent = LineSoft
	}

	textBlock := lipgloss.NewStyle().Background(bg).Foreground(fg).Render("Ag")
	textBlock = padRaw(textBlock, half)
	accentBlock := lipgloss.NewStyle().Background(accent).Render(strings.Repeat(" ", rest))
	return textBlock + accentBlock
}

// ColorStrip renders a row of single-column solid blocks, one per color, up to
// width columns. Missing/invalid colors are skipped.
func ColorStrip(colors []lipgloss.Color, width int) string {
	var b strings.Builder
	n := width
	if n < len(colors) {
		n = len(colors)
	}
	for i := 0; i < n && i < len(colors); i++ {
		if colors[i] == "" {
			continue
		}
		b.WriteString(lipgloss.NewStyle().Background(colors[i]).Render(" "))
	}
	return b.String()
}

func ActionText(key, label string) string {
	key = strings.TrimSpace(key)
	if key == "" {
		return label
	}
	if len([]rune(key)) == 1 {
		return underlineFirstMatch(label, key, Accent)
	}
	return lipgloss.NewStyle().Foreground(Accent).Underline(true).Render(key) + " " + label
}

func HelpText(items ...string) string {
	return SubtleText.Render(strings.Join(items, "  "))
}

func HelpItem(key, label string) string {
	return lipgloss.NewStyle().Foreground(Accent).Underline(true).Render(key) + " " + label
}

func StatusPill(label string, ok bool) string {
	style := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(LineSoft).
		Foreground(Subtle).
		Padding(0, 1)
	if ok {
		style = style.BorderForeground(Accent).Foreground(Accent)
	}
	return style.Render(label)
}

func MiniPreview(title, subtitle string, width int) string {
	width = max(18, width)
	inner := max(12, width-2)
	top := lipgloss.NewStyle().Background(LineSoft).Width(inner).Render(" ")
	body := lipgloss.NewStyle().Background(Background).Foreground(Text).Width(inner).Render(" " + TruncatePlain(title, max(1, inner-2)))
	body2 := lipgloss.NewStyle().Background(Background).Foreground(Muted).Width(inner).Render(" " + TruncatePlain(subtitle, max(1, inner-2)))
	fill := lipgloss.NewStyle().Background(Background).Width(inner).Render(" ")
	return lipgloss.NewStyle().
		Border(lipgloss.ThickBorder()).
		BorderForeground(LineSoft).
		Padding(0, 1).
		Render(strings.Join([]string{top, body, body2, fill}, "\n"))
}

func underlineFirstMatch(label, key string, color lipgloss.Color) string {
	lowerKey := strings.ToLower(key)
	var out strings.Builder
	done := false
	for _, r := range label {
		ch := string(r)
		if !done && strings.ToLower(ch) == lowerKey {
			out.WriteString(lipgloss.NewStyle().Foreground(color).Underline(true).Render(ch))
			done = true
			continue
		}
		out.WriteString(ch)
	}
	if done {
		return out.String()
	}
	return lipgloss.NewStyle().Foreground(color).Underline(true).Render(strings.ToUpper(key)) + " " + label
}

func padRaw(s string, width int) string {
	w := lipgloss.Width(s)
	if w >= width {
		return s
	}
	return s + strings.Repeat(" ", width-w)
}

var (
	Background = lipgloss.Color("#050505")
	Panel      = lipgloss.Color("#2b2b2b")
	PanelSoft  = lipgloss.Color("#343434")
	Line       = lipgloss.Color("#767676")
	LineSoft   = lipgloss.Color("#4d4d4d")
	Text       = lipgloss.Color("#eeeeee")
	Muted      = lipgloss.Color("#a7a7a7")
	Subtle     = lipgloss.Color("#7d7d7d")
	Accent     = lipgloss.Color("#20d6c7")
	Danger     = lipgloss.Color("#ff6b6b")
	Warn       = lipgloss.Color("#ffd166")
)

var (
	Screen = lipgloss.NewStyle().
		Background(Background).
		Foreground(Text)

	Title = lipgloss.NewStyle().
		Foreground(Text).
		Bold(true)

	Section = lipgloss.NewStyle().
		Foreground(Muted).
		Bold(true)

	MutedText = lipgloss.NewStyle().
			Foreground(Muted)

	SubtleText = lipgloss.NewStyle().
			Foreground(Subtle)

	OKText = lipgloss.NewStyle().
		Foreground(Accent)

	DangerText = lipgloss.NewStyle().
			Foreground(Danger)

	WarnText = lipgloss.NewStyle().
			Foreground(Warn)

	PanelBox = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(Line).
			Background(Panel).
			Padding(1, 2)

	Button = lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(Line).
		Background(Panel).
		Foreground(Text).
		Padding(0, 2).
		MarginRight(1)

	PrimaryButton = Button.Copy().
			BorderForeground(Accent).
			Foreground(Accent).
			Bold(true)

	DisabledButton = Button.Copy().
			BorderForeground(LineSoft).
			Foreground(Subtle)
)
