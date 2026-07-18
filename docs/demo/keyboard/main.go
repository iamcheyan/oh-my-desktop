package main

import (
	"fmt"
	"os"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

var (
	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#FAFAFA")).
			MarginBottom(1)

	helpStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#626262")).
			MarginTop(1)

	keyInfoStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#04B575")).
			Bold(true)

	groupLabelStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#7D56F4")).
			Italic(true)

	bgNormal   = lipgloss.Color("#2b2b2b")
	bgSelected = lipgloss.Color("#7D56F4")
	bgPressed  = lipgloss.Color("#FF6B6B")
	fgNormal   = lipgloss.Color("#eeeeee")
)

type keyDef struct {
	label string
	w     int
	code  string
}

func k(label string, w int, code string) keyDef {
	return keyDef{label: label, w: w, code: code}
}

func pad(s string, w int) string {
	// strip existing ANSI for width calculation
	visible := stripAnsi(s)
	gap := w - len(visible)
	if gap < 0 {
		gap = 0
	}
	return s + strings.Repeat(" ", gap)
}

func stripAnsi(s string) string {
	var out strings.Builder
	inEscape := false
	for _, r := range s {
		if r == '\x1b' {
			inEscape = true
			continue
		}
		if inEscape {
			if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') {
				inEscape = false
			}
			continue
		}
		out.WriteRune(r)
	}
	return out.String()
}

func renderKey(k keyDef, isSelected, isPressed bool) string {
	if k.label == "" {
		return strings.Repeat(" ", k.w)
	}

	var s lipgloss.Style
	switch {
	case isSelected && isPressed:
		s = lipgloss.NewStyle().Background(bgPressed).Foreground(fgNormal).Bold(true)
	case isSelected:
		s = lipgloss.NewStyle().Background(bgSelected).Foreground(fgNormal).Bold(true)
	case isPressed:
		s = lipgloss.NewStyle().Background(bgPressed).Foreground(fgNormal).Bold(true)
	default:
		s = lipgloss.NewStyle().Background(bgNormal).Foreground(fgNormal)
	}

	label := k.label
	if len(label) > k.w {
		label = label[:k.w]
	}

	rendered := s.Render(label)
	return pad(rendered, k.w)
}

type model struct {
	keys      [][]keyDef
	numpad    [][]keyDef
	selRow    int
	selCol    int
	arrowKeys []keyDef
	arrowSel  int
	focusArea int
	pressed   map[string]bool
	keyCode   string
	width     int
	height    int
}

func buildKeyboard() ([][]keyDef, [][]keyDef, []keyDef) {
	mainKeys := [][]keyDef{
		// Row 0: Esc  F1-F4  F5-F8  F9-F12  PrtSc ScrLk Pause  Ins Hom PgUp Del End PgDn
		{
			k("Esc", 4, "escape"),
			k("F1", 3, "F1"), k("F2", 3, "F2"), k("F3", 3, "F3"), k("F4", 3, "F4"),
			k("F5", 3, "F5"), k("F6", 3, "F6"), k("F7", 3, "F7"), k("F8", 3, "F8"),
			k("F9", 3, "F9"), k("F10", 3, "F10"), k("F11", 3, "F11"), k("F12", 3, "F12"),
			k("PrSc", 4, "Print"), k("SL", 3, "ScrollLock"), k("Pau", 3, "Pause"),
			k("Ins", 3, "Insert"), k("Hom", 3, "Home"), k("PgU", 3, "PageUp"),
			k("Del", 3, "Delete"), k("End", 3, "End"), k("PgD", 3, "PageDown"),
		},
		// Row 1: ` 1-9 0 - =
		{
			k("`", 3, "`"), k("1", 3, "1"), k("2", 3, "2"), k("3", 3, "3"),
			k("4", 3, "4"), k("5", 3, "5"), k("6", 3, "6"), k("7", 3, "7"),
			k("8", 3, "8"), k("9", 3, "9"), k("0", 3, "0"), k("-", 3, "-"),
			k("=", 3, "="), k("BkSp", 6, "backspace"),
		},
		// Row 2: Tab Q-P [ ] \
		{
			k("Tab", 5, "tab"),
			k("Q", 3, "q"), k("W", 3, "w"), k("E", 3, "e"), k("R", 3, "r"),
			k("T", 3, "t"), k("Y", 3, "y"), k("U", 3, "u"), k("I", 3, "i"),
			k("O", 3, "o"), k("P", 3, "p"),
			k("[", 3, "["), k("]", 3, "]"), k("\\", 5, "\\"),
		},
		// Row 3: Caps A-L ; '
		{
			k("Caps", 6, "capslock"),
			k("A", 3, "a"), k("S", 3, "s"), k("D", 3, "d"), k("F", 3, "f"),
			k("G", 3, "g"), k("H", 3, "h"), k("J", 3, "j"), k("K", 3, "k"),
			k("L", 3, "l"),
			k(";", 3, ";"), k("'", 3, "'"), k("Enter", 6, "enter"),
		},
		// Row 4: Shift Z-M , . / Shift
		{
			k("Shift", 8, "shift"),
			k("Z", 3, "z"), k("X", 3, "x"), k("C", 3, "c"), k("V", 3, "v"),
			k("B", 3, "b"), k("N", 3, "n"), k("M", 3, "m"),
			k(",", 3, ","), k(".", 3, "."), k("/", 3, "/"),
			k("Shift", 8, "shift"),
		},
		// Row 5: Ctrl Win Alt SPC Alt Win Fn Ctrl
		{
			k("Ctrl", 5, "ctrl"),
			k("Win", 4, "Meta"),
			k("Alt", 4, "alt"),
			k("", 22, "Space"),
			k("Alt", 4, "alt"),
			k("Win", 4, "Meta"),
			k("Fn", 3, ""),
			k("Ctrl", 5, "ctrl"),
		},
	}

	numpad := [][]keyDef{
		// Row 0: NumLk / * -
		{
			k("Num", 4, "NumLock"), k("/", 3, "NumpadDivide"),
			k("*", 3, "NumpadMultiply"), k("-", 3, "NumpadSubtract"),
		},
		// Row 1: 7 8 9 +
		{
			k("7", 3, "Numpad7"), k("8", 3, "Numpad8"), k("9", 3, "Numpad9"),
			k("+", 3, "NumpadAdd"),
		},
		// Row 2: 4 5 6
		{
			k("4", 3, "Numpad4"), k("5", 3, "Numpad5"), k("6", 3, "Numpad6"),
		},
		// Row 3: 1 2 3 Ent
		{
			k("1", 3, "Numpad1"), k("2", 3, "Numpad2"), k("3", 3, "Numpad3"),
			k("Ent", 4, "NumpadEnter"),
		},
		// Row 4: 0 . Del
		{
			k("0", 6, "Numpad0"), k(".", 3, "NumpadDecimal"), k("Del", 4, "Delete"),
		},
	}

	arrowKeys := []keyDef{
		k("▲", 3, "Up"),
		k("◀", 3, "Left"), k("▼", 3, "Down"), k("▶", 3, "Right"),
	}

	return mainKeys, numpad, arrowKeys
}

func initialModel() model {
	mainKeys, numpad, arrowKeys := buildKeyboard()
	return model{
		keys:      mainKeys,
		numpad:    numpad,
		selRow:    0,
		selCol:    0,
		arrowKeys: arrowKeys,
		arrowSel:  0,
		focusArea: 0,
		pressed:   make(map[string]bool),
	}
}

func (m model) Init() tea.Cmd { return nil }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil

	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			return m, tea.Quit

		case "tab":
			if m.focusArea == 0 {
				m.focusArea = 1
			} else {
				m.focusArea = 0
			}

		case "up", "k":
			if m.focusArea == 0 {
				m.moveUp()
			} else if m.arrowSel == 0 {
				m.arrowSel = 0
			} else if m.arrowSel == 1 || m.arrowSel == 2 || m.arrowSel == 3 {
				m.arrowSel = 0
			}

		case "down", "j":
			if m.focusArea == 0 {
				m.moveDown()
			} else if m.arrowSel == 0 {
				m.arrowSel = 2
			}

		case "left", "h":
			if m.focusArea == 0 {
				m.moveLeft()
			} else if m.arrowSel == 1 {
				m.arrowSel = 1
			} else if m.arrowSel == 2 || m.arrowSel == 3 {
				m.arrowSel = 1
			}

		case "right", "l":
			if m.focusArea == 0 {
				m.moveRight()
			} else if m.arrowSel == 0 {
				m.arrowSel = 2
			} else if m.arrowSel == 1 || m.arrowSel == 2 {
				m.arrowSel = 3
			}

		case "enter", " ":
			if m.focusArea == 0 {
				m.toggleKey()
			} else {
				m.toggleArrow()
			}
		}
	}
	return m, nil
}

func (m *model) moveUp() {
	for r := m.selRow - 1; r >= 0; r-- {
		if r < len(m.keys) && m.selCol < len(m.keys[r]) {
			m.selRow = r
			return
		}
	}
}

func (m *model) moveDown() {
	for r := m.selRow + 1; r < len(m.keys); r++ {
		if m.selCol < len(m.keys[r]) {
			m.selRow = r
			return
		}
	}
}

func (m *model) moveLeft() {
	for c := m.selCol - 1; c >= 0; c-- {
		if c < len(m.keys[m.selRow]) {
			m.selCol = c
			return
		}
	}
}

func (m *model) moveRight() {
	for c := m.selCol + 1; c < len(m.keys[m.selRow]); c++ {
		m.selCol = c
		return
	}
}

func (m *model) toggleKey() {
	if m.selRow >= len(m.keys) || m.selCol >= len(m.keys[m.selRow]) {
		return
	}
	key := m.keys[m.selRow][m.selCol]
	if key.code == "" {
		return
	}
	m.pressed[key.code] = !m.pressed[key.code]
	if m.pressed[key.code] {
		m.keyCode = key.code
	} else {
		m.keyCode = ""
	}
}

func (m *model) toggleArrow() {
	if m.arrowSel >= len(m.arrowKeys) {
		return
	}
	key := m.arrowKeys[m.arrowSel]
	if key.code == "" {
		return
	}
	m.pressed[key.code] = !m.pressed[key.code]
	if m.pressed[key.code] {
		m.keyCode = key.code
	} else {
		m.keyCode = ""
	}
}

func (m model) renderRow(keys []keyDef, rowIdx int) string {
	var parts []string
	for col, k := range keys {
		isSel := m.focusArea == 0 && rowIdx == m.selRow && col == m.selCol
		isPrs := m.pressed[k.code]
		parts = append(parts, renderKey(k, isSel, isPrs))
	}
	return strings.Join(parts, "")
}

func (m model) renderNumpadRow(keys []keyDef) string {
	var parts []string
	for _, k := range keys {
		isPrs := m.pressed[k.code]
		parts = append(parts, renderKey(k, false, isPrs))
	}
	return strings.Join(parts, "")
}

func (m model) renderArrowBlock() string {
	var lines []string

	k0 := m.arrowKeys[0]
	k1 := m.arrowKeys[1]
	k2 := m.arrowKeys[2]
	k3 := m.arrowKeys[3]

	s0 := m.focusArea == 1 && m.arrowSel == 0
	s1 := m.focusArea == 1 && m.arrowSel == 1
	s2 := m.focusArea == 1 && m.arrowSel == 2
	s3 := m.focusArea == 1 && m.arrowSel == 3

	p0 := m.pressed[k0.code]
	p1 := m.pressed[k1.code]
	p2 := m.pressed[k2.code]
	p3 := m.pressed[k3.code]

	lines = append(lines,
		renderKey(keyDef{w: 3}, false, false)+
			renderKey(k0, s0, p0)+
			renderKey(keyDef{w: 3}, false, false),
		renderKey(k1, s1, p1)+
			renderKey(k2, s2, p2)+
			renderKey(k3, s3, p3),
	)
	return strings.Join(lines, "\n")
}

func (m model) rowWidth(keys []keyDef) int {
	w := 0
	for _, k := range keys {
		w += k.w
	}
	return w
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func (m model) View() string {
	var b strings.Builder

	b.WriteString(titleStyle.Render("108-Key Keyboard Layout"))
	b.WriteString("\n")

	// Key code display
	keyCodeLine := "  "
	if m.keyCode != "" {
		keyCodeLine += "Key: " + keyInfoStyle.Render(m.keyCode)
	} else {
		code := ""
		if m.focusArea == 0 && m.selRow < len(m.keys) && m.selCol < len(m.keys[m.selRow]) {
			code = m.keys[m.selRow][m.selCol].code
		} else if m.focusArea == 1 && m.arrowSel < len(m.arrowKeys) {
			code = m.arrowKeys[m.arrowSel].code
		}
		if code != "" {
			keyCodeLine += "Key: " + lipgloss.NewStyle().Foreground(lipgloss.Color("#626262")).Render(code)
		}
	}
	b.WriteString(keyCodeLine)
	b.WriteString("\n\n")

	targetW := mainKeyRowWidth()

	// Find max width of main keyboard rows
	targetW := 0
	for rowIdx := 0; rowIdx < 6 && rowIdx < len(m.keys); rowIdx++ {
		targetW = max(targetW, m.rowWidth(m.keys[rowIdx]))
	}

	// Render main keyboard rows 0-5, with numpad and arrow block
	for rowIdx := 0; rowIdx < 6 && rowIdx < len(m.keys); rowIdx++ {
		// Main section
		mainPart := m.renderRow(m.keys[rowIdx], rowIdx)

		// Pad main section to fixed width
		visibleMain := stripAnsi(mainPart)
		padNeeded := targetW - len(visibleMain)
		if padNeeded < 0 {
			padNeeded = 0
		}
		mainPart += strings.Repeat(" ", padNeeded)

		// Numpad section
		numpadPart := ""
		if rowIdx < len(m.numpad) {
			numpadPart = "  " + m.renderNumpadRow(m.numpad[rowIdx])
		}

		b.WriteString("  ")
		b.WriteString(mainPart)
		b.WriteString(numpadPart)

		// Arrow block on row 4 and 5
		if rowIdx == 4 {
			arrowLines := strings.Split(m.renderArrowBlock(), "\n")
			b.WriteString("   " + arrowLines[0])
		}
		if rowIdx == 5 {
			arrowLines := strings.Split(m.renderArrowBlock(), "\n")
			if len(arrowLines) > 1 {
				b.WriteString(strings.Repeat(" ", 3) + arrowLines[1])
			}
		}

		b.WriteString("\n")
	}

	// Legend
	b.WriteString("\n")
	b.WriteString(groupLabelStyle.Render("  ← → ↑ ↓ move   Tab switch area   Enter/Space toggle   q quit"))
	b.WriteString("\n")

	return b.String()
}

func main() {
	p := tea.NewProgram(
		initialModel(),
		tea.WithAltScreen(),
		tea.WithMouseCellMotion(),
	)

	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
