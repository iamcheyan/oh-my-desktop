package ui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// PrimaryLine is the single main CTA for a page state.
// Example: "→ Connect (enter)"
func PrimaryLine(label, key string, enabled bool) string {
	key = strings.TrimSpace(key)
	if key == "" {
		key = "enter"
	}
	style := lipgloss.NewStyle().Foreground(Muted)
	prefix := "  "
	if enabled {
		style = lipgloss.NewStyle().Foreground(Accent).Bold(true)
		prefix = "→ "
	}
	text := prefix + label
	if key != "" {
		text += " (" + key + ")"
	}
	return style.Render(text)
}

// ActionLine is a secondary text action: "Setup keyd (s)".
// No border. Danger styling is opt-in via DangerActionLine.
func ActionLine(key, label string, enabled bool) string {
	style := lipgloss.NewStyle().Foreground(Subtle)
	if enabled {
		style = lipgloss.NewStyle().Foreground(Text)
	}
	key = strings.TrimSpace(key)
	label = strings.TrimSpace(label)
	if key == "" {
		return style.Render(label)
	}
	return style.Render(label + " (" + key + ")")
}

// DangerActionLine is a destructive secondary action (delete/remove).
func DangerActionLine(key, label string, enabled bool) string {
	style := lipgloss.NewStyle().Foreground(Subtle)
	if enabled {
		style = lipgloss.NewStyle().Foreground(Danger)
	}
	key = strings.TrimSpace(key)
	label = strings.TrimSpace(label)
	if key == "" {
		return style.Render(label)
	}
	return style.Render(label + " (" + key + ")")
}

// ActionMnemonic underlines the mnemonic letter inside label (single-char keys).
// Prefer ActionLine for new UI; this exists for pages that already teach
// mnemonics via underline.
func ActionMnemonic(key, label string, enabled bool) string {
	if !enabled {
		return lipgloss.NewStyle().Foreground(Subtle).Render(label)
	}
	return ActionText(key, label)
}

// ToggleOpts configures a checkbox row.
type ToggleOpts struct {
	Focused  bool
	Dimmed   bool // parent disabled — whole row subtle
	Trailing string
}

// ToggleLine renders "[X] Label  trailing".
func ToggleLine(on bool, label string, opts ToggleOpts) string {
	box := "[ ]"
	if on {
		box = "[X]"
	}
	style := lipgloss.NewStyle().Foreground(Text)
	trailStyle := lipgloss.NewStyle().Foreground(Accent)
	if opts.Dimmed {
		style = lipgloss.NewStyle().Foreground(Subtle)
		trailStyle = lipgloss.NewStyle().Foreground(Subtle)
	} else if opts.Focused {
		style = lipgloss.NewStyle().Foreground(Accent).Bold(true)
	}
	line := box + " " + style.Render(label)
	if strings.TrimSpace(opts.Trailing) != "" {
		line += "  " + trailStyle.Render(opts.Trailing)
	}
	return line
}

// CycleLine renders "Label: value (key)" for enum cycling.
func CycleLine(label, value, key string, focused bool) string {
	style := lipgloss.NewStyle().Foreground(Text)
	valStyle := lipgloss.NewStyle().Foreground(Accent)
	if focused {
		style = lipgloss.NewStyle().Foreground(Accent).Bold(true)
	}
	key = strings.TrimSpace(key)
	text := style.Render(label+":") + " " + valStyle.Render(value)
	if key != "" {
		text += " " + SubtleText.Render("("+key+")")
	}
	return text
}

// SegmentedLine renders "Label: a · b · c" with the selected option accented.
func SegmentedLine(label string, options []string, selected int, focused bool) string {
	parts := make([]string, 0, len(options))
	for i, opt := range options {
		if i == selected {
			parts = append(parts, OKText.Bold(true).Render(opt))
		} else {
			parts = append(parts, SubtleText.Render(opt))
		}
	}
	headStyle := lipgloss.NewStyle().Foreground(Text)
	if focused {
		headStyle = lipgloss.NewStyle().Foreground(Accent).Bold(true)
	}
	head := headStyle.Render(label + ":")
	return head + " " + strings.Join(parts, SubtleText.Render(" · "))
}

// ListItemOpts configures a navigable list row.
type ListItemOpts struct {
	Focused   bool
	Connected bool // true => ●, false => ○ (ignored if Bullet override set)
	Offline   bool // appends " (offline)" when true
	Bullet    string // if non-empty, overrides ●/○ (e.g. custom markers)
}

// ListItem renders a master-list row with series-wide focus language:
//
//	▸ name          focused
//	● name          connected idle
//	○ name (offline)
func ListItem(name string, opts ListItemOpts) string {
	bullet := opts.Bullet
	if bullet == "" {
		if opts.Connected {
			bullet = "●"
		} else {
			bullet = "○"
		}
	}
	label := name
	if opts.Offline {
		label += " (offline)"
	}

	if opts.Focused {
		return OKText.Bold(true).Render("▸ "+label)
	}
	if opts.Connected && !opts.Offline {
		return OKText.Render(bullet) + " " + lipgloss.NewStyle().Foreground(Text).Render(label)
	}
	return SubtleText.Render(bullet+" "+label)
}

// KVLine is a simple label/value row for specs cards.
func KVLine(label, value string, width int) string {
	if width < 12 {
		width = 12
	}
	left := lipgloss.NewStyle().Foreground(Text).Render(label)
	gap := 2
	remain := width - lipgloss.Width(label) - gap
	if remain < 4 {
		remain = 4
	}
	right := lipgloss.NewStyle().Foreground(Muted).Render(TruncatePlain(value, remain))
	return left + strings.Repeat(" ", gap) + right
}

// ProfileEnabledLine is a focused-capable "Profile: [X] Enabled" row.
func ProfileEnabledLine(on, focused bool) string {
	box := "[ ]"
	if on {
		box = "[X]"
	}
	text := fmt.Sprintf("Profile: %s Enabled", box)
	style := lipgloss.NewStyle().Foreground(Text)
	if focused {
		style = lipgloss.NewStyle().Foreground(Accent).Bold(true)
	}
	return style.Render(text)
}
