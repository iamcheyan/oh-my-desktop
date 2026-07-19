package ui

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
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

// IconButton renders an optional Nerd Font glyph followed by an ActionText
// mnemonic. Prefer ActionLine / PrimaryLine for ordinary page actions
// (docs/settings-tui-visual-system.md).
func IconButton(icon, key, label string) string {
	text := ActionText(key, label)
	if icon == "" {
		return text
	}
	return icon + "  " + text
}

// ActionButton is a legacy alias for ActionLine (no border).
// Prefer ActionLine in new code.
func ActionButton(icon, key, label string, active bool) string {
	_ = icon
	return ActionLine(key, label, !active)
}

// PrimaryActionButton is a legacy alias for PrimaryLine.
func PrimaryActionButton(icon, key, label string) string {
	_ = icon
	return PrimaryLine(label, key, true)
}

// DisabledActionButton is a legacy alias for a disabled ActionLine.
func DisabledActionButton(icon, key, label string) string {
	_ = icon
	return ActionLine(key, label, false)
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

// ButtonView / PrimaryButtonView / DisabledButtonView keep bordered chips for
// rare modal chrome only. Ordinary settings actions must use PrimaryLine /
// ActionLine (no border). See docs/settings-tui-visual-system.md.
func ButtonView(text string, active bool) string {
	style := Button.Copy().Padding(0, 1)
	if active {
		style = style.BorderForeground(Accent).Foreground(Accent).Bold(true)
	}
	return style.Render(PreserveBackground(text, Panel))
}

func DisabledButtonView(text string) string {
	return DisabledButton.Copy().Padding(0, 1).Render(PreserveBackground(text, Panel))
}

func PrimaryButtonView(text string) string {
	return PrimaryButton.Copy().Padding(0, 1).Render(PreserveBackground(text, Panel))
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

func InitTheme(root string) {
	colorsPath := filepath.Join(root, "current", "theme", "colors.toml")
	file, err := os.Open(colorsPath)
	if err != nil {
		home, _ := os.UserHomeDir()
		colorsPath = filepath.Join(home, ".config", "omd", "current", "theme", "colors.toml")
		file, err = os.Open(colorsPath)
	}

	bgStr := "#050505"
	fgStr := "#eeeeee"
	accentStr := "#20d6c7"

	if err == nil {
		defer file.Close()
		scanner := bufio.NewScanner(file)
		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}
			parts := strings.SplitN(line, "=", 2)
			if len(parts) != 2 {
				continue
			}
			key := strings.TrimSpace(parts[0])
			val := strings.TrimSpace(parts[1])
			val = strings.Trim(val, `"'`)
			if !strings.HasPrefix(val, "#") {
				val = "#" + val
			}
			switch key {
			case "background":
				bgStr = val
			case "foreground":
				fgStr = val
			case "accent":
				accentStr = val
			}
		}
	}

	bgC := lipgloss.Color(bgStr)
	fgC := lipgloss.Color(fgStr)
	accentC := lipgloss.Color(accentStr)

	Background = bgC
	Text = fgC
	Accent = accentC
	Panel = blend(bgC, fgC, 0.08)
	PanelSoft = blend(bgC, fgC, 0.14)
	Line = blend(bgC, fgC, 0.28)
	LineSoft = blend(bgC, fgC, 0.18)
	Muted = blend(bgC, fgC, 0.68)
	Subtle = blend(bgC, fgC, 0.45)

	// Rebuild styles
	Screen = lipgloss.NewStyle().Background(Background).Foreground(Text)
	Title = lipgloss.NewStyle().Foreground(Text).Bold(true)
	Section = lipgloss.NewStyle().Foreground(Muted).Bold(true)
	MutedText = lipgloss.NewStyle().Foreground(Muted)
	SubtleText = lipgloss.NewStyle().Foreground(Subtle)
	OKText = lipgloss.NewStyle().Foreground(Accent)
	DangerText = lipgloss.NewStyle().Foreground(Danger)
	WarnText = lipgloss.NewStyle().Foreground(Warn)
	PanelBox = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(Line).Background(Panel).Padding(1, 2)
	Button = lipgloss.NewStyle().Border(lipgloss.NormalBorder()).BorderForeground(Line).Background(Panel).Foreground(Text).Padding(0, 2).MarginRight(1)
	PrimaryButton = Button.Copy().BorderForeground(Accent).Foreground(Accent).Bold(true)
	DisabledButton = Button.Copy().BorderForeground(LineSoft).Foreground(Subtle)
}

func blend(c1, c2 lipgloss.Color, ratio float64) lipgloss.Color {
	r1, g1, b1, ok1 := hexToRGB(string(c1))
	r2, g2, b2, ok2 := hexToRGB(string(c2))
	if !ok1 || !ok2 {
		return c1
	}
	r := int(float64(r1)*(1-ratio) + float64(r2)*ratio)
	g := int(float64(g1)*(1-ratio) + float64(g2)*ratio)
	b := int(float64(b1)*(1-ratio) + float64(b2)*ratio)
	return lipgloss.Color(fmt.Sprintf("#%02x%02x%02x", r, g, b))
}

func hexToRGB(hex string) (int, int, int, bool) {
	hex = strings.TrimPrefix(hex, "#")
	if len(hex) != 6 {
		return 0, 0, 0, false
	}
	var r, g, b int
	_, err := fmt.Sscanf(hex, "%02x%02x%02x", &r, &g, &b)
	if err != nil {
		return 0, 0, 0, false
	}
	return r, g, b, true
}
