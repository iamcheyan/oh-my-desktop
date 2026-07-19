package ui

import (
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// Tone classifies health for status dots and hero lights.
type Tone int

const (
	ToneOK Tone = iota
	ToneWarn
	ToneDanger
	ToneIdle
)

// HeroOpts configures the page hero line (title row + optional subtitle).
type HeroOpts struct {
	Tone    Tone
	Busy    bool
	Message string // optional short note (error / status), truncated by caller if needed
}

// Page is the shared settings TUI chrome. Feature pages fill content; this
// type owns padding, columns, help, and pending footer framing.
// See docs/settings-tui-visual-system.md.
type Page struct {
	Width   int
	Height  int
	Hero    string // pre-rendered hero block (use Hero())
	Left    string
	Right   string // empty => single column
	Wide    bool   // two columns when true and Right non-empty
	Help    []string
	Pending string // empty => hidden; use PendingLine()
}

// StatusDot renders the ● health indicator.
func StatusDot(tone Tone) string {
	style := SubtleText
	switch tone {
	case ToneOK:
		style = OKText
	case ToneWarn:
		style = WarnText
	case ToneDanger:
		style = DangerText
	}
	return style.Render("●")
}

// SectionTitle is the muted section header used by all settings pages.
func SectionTitle(text string) string {
	return Section.Render(text)
}

// Hero builds the standard title block:
//
//	● Title working…
//	subtitle
func Hero(title, subtitle string, opts HeroOpts) string {
	line := StatusDot(opts.Tone) + " " + Title.Render(title)
	if opts.Busy {
		line += " " + OKText.Render("working…")
	}
	if strings.TrimSpace(opts.Message) != "" {
		msgStyle := MutedText
		switch opts.Tone {
		case ToneDanger:
			msgStyle = DangerText
		case ToneWarn:
			msgStyle = WarnText
		case ToneOK:
			msgStyle = OKText
		}
		line += " " + msgStyle.Render(opts.Message)
	}
	if strings.TrimSpace(subtitle) == "" {
		return line
	}
	return line + "\n" + MutedText.Render(subtitle)
}

// PendingLine formats the draft Apply/Discard footer.
func PendingLine(applyKey, discardKey string) string {
	if applyKey == "" {
		applyKey = "a"
	}
	if discardKey == "" {
		discardKey = "x"
	}
	return OKText.Render("Pending changes · Apply (" + applyKey + ") · Discard (" + discardKey + ")")
}

// RenderPage paints the shared settings chrome. Returns "Initializing..." until
// terminal size is known (startup overflow guard).
func RenderPage(p Page) string {
	if p.Width <= 0 || p.Height <= 0 {
		return "Initializing..."
	}

	const (
		screenPaddingX = 2 // Padding(1,1) total horizontal
		screenPaddingY = 2
		columnGap      = 2
	)

	helpText := ""
	if len(p.Help) > 0 {
		helpText = HelpText(p.Help...)
	}
	pending := strings.TrimSpace(p.Pending)

	fixedRows := 0
	if helpText != "" {
		fixedRows++
	}
	if pending != "" {
		fixedRows++
	}
	// Hero may be multi-line; reserve its measured height after we know width.
	contentW := p.Width - screenPaddingX
	if contentW < 40 {
		contentW = 40
	}

	hero := strings.TrimSpace(p.Hero)
	heroH := 0
	if hero != "" {
		heroH = strings.Count(hero, "\n") + 1
	}
	fixedRows += heroH

	contentH := p.Height - screenPaddingY - fixedRows
	if contentH < 12 {
		contentH = 12
	}

	var body string
	if p.Wide && strings.TrimSpace(p.Right) != "" {
		leftW := min(54, max(28, contentW/3))
		rightW := contentW - leftW - columnGap
		if rightW < 30 {
			rightW = 30
			leftW = max(24, contentW-columnGap-rightW)
		}
		left := PreserveBackground(FitBlock(p.Left, leftW, contentH), Background)
		right := PreserveBackground(FitBlock(p.Right, rightW, contentH), Background)
		body = lipgloss.JoinHorizontal(lipgloss.Top, left, strings.Repeat(" ", columnGap), right)
	} else {
		combined := p.Left
		if strings.TrimSpace(p.Right) != "" {
			if strings.TrimSpace(combined) != "" {
				combined += "\n\n"
			}
			combined += p.Right
		}
		body = PreserveBackground(FitBlock(combined, contentW, contentH), Background)
	}

	parts := make([]string, 0, 4)
	if hero != "" {
		parts = append(parts, hero)
	}
	parts = append(parts, body)
	if helpText != "" {
		parts = append(parts, helpText)
	}
	if pending != "" {
		parts = append(parts, pending)
	}

	return Screen.Padding(1, 1).Render(lipgloss.JoinVertical(lipgloss.Left, parts...))
}

// DefaultWide returns true when a two-column layout is appropriate.
func DefaultWide(contentWidth int) bool {
	return contentWidth >= 90
}
