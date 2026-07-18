package ui

import (
	"strings"
	"unicode/utf8"

	"github.com/charmbracelet/lipgloss"
)

func BoolStatus(ok bool) string {
	if ok {
		return OKText.Render("up")
	}
	return SubtleText.Render("down")
}

func Row(label, value string, width int) string {
	if width < 20 {
		width = 20
	}
	labelWidth := min(18, max(10, width/3))
	valueWidth := max(8, width-labelWidth-2)

	left := lipgloss.NewStyle().Foreground(Text).Width(labelWidth).Render(label)
	right := lipgloss.NewStyle().Foreground(Muted).Width(valueWidth).Align(lipgloss.Right).Render(value)
	return left + right
}

func ClipLines(lines []string, count int) []string {
	if count <= 0 {
		return nil
	}
	if len(lines) <= count {
		return lines
	}
	return lines[len(lines)-count:]
}

func TruncatePlain(text string, width int) string {
	if width <= 0 {
		return ""
	}

	text = strings.ReplaceAll(text, "\t", "  ")
	if lipgloss.Width(text) <= width {
		return text
	}
	if width <= 1 {
		return "…"
	}

	var b strings.Builder
	used := 0
	for len(text) > 0 {
		r, size := utf8.DecodeRuneInString(text)
		if r == utf8.RuneError && size == 0 {
			break
		}
		rw := lipgloss.Width(string(r))
		if used+rw > width-1 {
			break
		}
		b.WriteRune(r)
		used += rw
		text = text[size:]
	}
	b.WriteRune('…')
	return b.String()
}

func JoinNonEmpty(lines ...string) string {
	out := make([]string, 0, len(lines))
	for _, line := range lines {
		if strings.TrimSpace(line) != "" {
			out = append(out, line)
		}
	}
	return strings.Join(out, "\n")
}

// FitBlock trims (or pads) a multi-line string to exactly height rows and
// width columns, so it fits a fixed panel interior without overflowing.
// Long lines are truncated to width (handling ANSI styling); short lines
// are right-padded with spaces. Excess rows are dropped; missing rows are
// filled with blank lines. This guarantees the rendered block has a fixed
// footprint regardless of content length.
func FitBlock(text string, width, height int) string {
	if width < 0 {
		width = 0
	}
	if height < 0 {
		height = 0
	}
	lines := strings.Split(text, "\n")
	if len(lines) > height {
		lines = lines[:height]
	}
	for i, line := range lines {
		lines[i] = padPlain(TruncateStyled(line, width), width)
	}
	for len(lines) < height {
		lines = append(lines, strings.Repeat(" ", width))
	}
	return strings.Join(lines, "\n")
}

// PreserveBackground forces the background color bg on all text and
// ensures any ANSI reset codes inside text do not leak and turn the
// background black.
func PreserveBackground(text string, bg lipgloss.Color) string {
	bgStyle := lipgloss.NewStyle().Background(bg)
	bgRendered := bgStyle.Render(" ")
	idx := strings.Index(bgRendered, " ")
	if idx < 0 {
		return text
	}
	bgSeq := bgRendered[:idx]
	textWithBg := strings.ReplaceAll(text, "\x1b[0m", "\x1b[0m"+bgSeq)
	return bgStyle.Render(textWithBg)
}

// TruncateStyled truncates a single line (which may contain ANSI escape
// sequences) to at most width visible columns, appending an ellipsis when
// truncation occurs. ANSI styling is preserved on the kept prefix and a
// reset is appended so trailing padding is not tinted.
func TruncateStyled(line string, width int) string {
	if width <= 0 {
		return ""
	}
	if lipgloss.Width(stripAnsi(line)) <= width {
		return line
	}
	if width <= 1 {
		return "…"
	}
	var b strings.Builder
	used := 0
	i := 0
	for i < len(line) {
		if line[i] == '\x1b' {
			seq, next := readAnsi(line, i)
			b.WriteString(seq)
			i = next
			continue
		}
		r, size := utf8.DecodeRuneInString(line[i:])
		if r == utf8.RuneError && size <= 1 {
			i++
			continue
		}
		rw := lipgloss.Width(string(r))
		if used+rw > width-1 {
			break
		}
		b.WriteRune(r)
		used += rw
		i += size
	}
	b.WriteString("…\x1b[0m")
	return b.String()
}

func padPlain(line string, width int) string {
	w := lipgloss.Width(stripAnsi(line))
	if w >= width {
		return line
	}
	return line + strings.Repeat(" ", width-w)
}

// readAnsi consumes one ANSI escape sequence starting at s[i] and returns
// the sequence together with the index just past it.
func readAnsi(s string, i int) (string, int) {
	if i >= len(s) || s[i] != '\x1b' {
		return s[i : i+1], i + 1
	}
	end := i + 1
	if end < len(s) && s[end] == ']' {
		// OSC: terminated by BEL or ST (ESC \)
		for end < len(s) {
			if s[end] == '\x07' {
				end++
				break
			}
			if s[end] == '\x1b' && end+1 < len(s) && s[end+1] == '\\' {
				end += 2
				break
			}
			end++
		}
		return s[i:end], end
	}
	// CSI/SS2 etc: ESC [ <params> <final byte>
	end++ // skip [
	for end < len(s) {
		c := s[end]
		if (c >= '0' && c <= '9') || c == ';' || c == '?' || c == '=' || c == '>' || c < ' ' {
			end++
			continue
		}
		end++
		break
	}
	return s[i:end], end
}

func stripAnsi(s string) string {
	var b strings.Builder
	i := 0
	for i < len(s) {
		if s[i] == '\x1b' {
			_, next := readAnsi(s, i)
			i = next
			continue
		}
		b.WriteByte(s[i])
		i++
	}
	return b.String()
}
