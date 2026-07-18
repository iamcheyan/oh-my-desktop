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

	keyInfoStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#04B575")).
			Bold(true)

	groupLabelStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#7D56F4")).
			Italic(true)
)

type keyDef struct {
	label string
	w     int
	code  string
}

func k(label string, w int, code string) keyDef {
	return keyDef{label: label, w: w, code: code}
}

// keyColors returns background colors for a key based on its state
func keyColors(isSelected, isPressed bool) (top, mid, bot string) {
	switch {
	case isSelected && isPressed:
		return "#FF8A8A", "#FF6B6B", "#CC4444"
	case isSelected:
		return "#9B7BF4", "#7D56F4", "#5A3DB8"
	case isPressed:
		return "#FF8A8A", "#FF6B6B", "#CC4444"
	default:
		return "#3a3a3a", "#2b2b2b", "#1a1a1a"
	}
}

func fgColor(isSelected, isPressed bool) string {
	if isSelected || isPressed {
		return "#FFFFFF"
	}
	return "#eeeeee"
}

// renderKeyBlock renders a key as 3 lines: top edge, label, bottom shadow
func renderKeyBlock(k keyDef, isSelected, isPressed bool) [3]string {
	if k.label == "" {
		blank := strings.Repeat(" ", k.w)
		return [3]string{blank, blank, blank}
	}

	w := k.w
	top, mid, bot := keyColors(isSelected, isPressed)
	fg := fgColor(isSelected, isPressed)

	// Center label
	label := k.label
	if len(label) > w-2 {
		label = label[:w-2]
	}
	leftPad := (w - 2 - len(label)) / 2
	rightPad := w - 2 - len(label) - leftPad
	centered := strings.Repeat(" ", leftPad) + label + strings.Repeat(" ", rightPad)

	topLine := lipgloss.NewStyle().Background(lipgloss.Color(top)).Foreground(lipgloss.Color(fg)).Render(strings.Repeat(" ", w))
	midLine := lipgloss.NewStyle().Background(lipgloss.Color(mid)).Foreground(lipgloss.Color(fg)).Render(" " + centered + " ")
	botLine := lipgloss.NewStyle().Background(lipgloss.Color(bot)).Render(strings.Repeat(" ", w))

	return [3]string{topLine, midLine, botLine}
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

func visibleWidth(s string) int {
	return len(stripAnsi(s))
}

func padRight(s string, targetW int) string {
	vw := visibleWidth(s)
	if vw >= targetW {
		return s
	}
	return s + strings.Repeat(" ", targetW-vw)
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
		// Row 0: Esc + F1-F12 + PrtSc ScrLk Pause
		{
			k("Esc", 4, "escape"),
			k("F1", 4, "F1"), k("F2", 4, "F2"), k("F3", 4, "F3"), k("F4", 4, "F4"),
			k("F5", 4, "F5"), k("F6", 4, "F6"), k("F7", 4, "F7"), k("F8", 4, "F8"),
			k("F9", 4, "F9"), k("F10", 4, "F10"), k("F11", 4, "F11"), k("F12", 4, "F12"),
			k("PrSc", 5, "Print"), k("SL", 4, "ScrollLock"), k("Pau", 4, "Pause"),
		},
		// Row 1: Ins Hom PgUp Del End PgDn
		{
			k("Ins", 4, "Insert"), k("Hom", 4, "Home"), k("PgU", 4, "PageUp"),
			k("Del", 4, "Delete"), k("End", 4, "End"), k("PgD", 4, "PageDown"),
		},
		// Row 2: ` 1-9 0 - = BkSp
		{
			k("`", 4, "`"), k("1", 4, "1"), k("2", 4, "2"), k("3", 4, "3"),
			k("4", 4, "4"), k("5", 4, "5"), k("6", 4, "6"), k("7", 4, "7"),
			k("8", 4, "8"), k("9", 4, "9"), k("0", 4, "0"), k("-", 4, "-"),
			k("=", 4, "="), k("BkSp", 6, "backspace"),
		},
		// Row 3: Tab Q-P [ ] \
		{
			k("Tab", 6, "tab"),
			k("Q", 4, "q"), k("W", 4, "w"), k("E", 4, "e"), k("R", 4, "r"),
			k("T", 4, "t"), k("Y", 4, "y"), k("U", 4, "u"), k("I", 4, "i"),
			k("O", 4, "o"), k("P", 4, "p"),
			k("[", 4, "["), k("]", 4, "]"), k("\\", 6, "\\"),
		},
		// Row 4: Caps A-L ; '
		{
			k("Caps", 6, "capslock"),
			k("A", 4, "a"), k("S", 4, "s"), k("D", 4, "d"), k("F", 4, "f"),
			k("G", 4, "g"), k("H", 4, "h"), k("J", 4, "j"), k("K", 4, "k"),
			k("L", 4, "l"),
			k(";", 4, ";"), k("'", 4, "'"), k("Enter", 6, "enter"),
		},
		// Row 5: Shift Z-M , . / Shift
		{
			k("Shift", 8, "shift"),
			k("Z", 4, "z"), k("X", 4, "x"), k("C", 4, "c"), k("V", 4, "v"),
			k("B", 4, "b"), k("N", 4, "n"), k("M", 4, "m"),
			k(",", 4, ","), k(".", 4, "."), k("/", 4, "/"),
			k("Shift", 8, "shift"),
		},
		// Row 6: Ctrl Win Alt Space Alt Win Fn Ctrl
		{
			k("Ctrl", 6, "ctrl"),
			k("Win", 5, "Meta"),
			k("Alt", 5, "alt"),
			k("", 24, "Space"),
			k("Alt", 5, "alt"),
			k("Win", 5, "Meta"),
			k("Fn", 4, ""),
			k("Ctrl", 6, "ctrl"),
		},
	}

	numpad := [][]keyDef{
		{
			k("Num", 5, "NumLock"), k("/", 4, "NumpadDivide"),
			k("*", 4, "NumpadMultiply"), k("-", 4, "NumpadSubtract"),
		},
		{
			k("7", 4, "Numpad7"), k("8", 4, "Numpad8"), k("9", 4, "Numpad9"),
			k("+", 4, "NumpadAdd"),
		},
		{
			k("4", 4, "Numpad4"), k("5", 4, "Numpad5"), k("6", 4, "Numpad6"),
		},
		{
			k("1", 4, "Numpad1"), k("2", 4, "Numpad2"), k("3", 4, "Numpad3"),
			k("Ent", 5, "NumpadEnter"),
		},
		{
			k("0", 6, "Numpad0"), k(".", 4, "NumpadDecimal"), k("Del", 5, "Delete"),
		},
	}

	arrowKeys := []keyDef{
		k("▲", 5, "Up"),
		k("◀", 4, "Left"), k("▼", 4, "Down"), k("▶", 4, "Right"),
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
			} else if m.arrowSel != 0 {
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
			} else if m.arrowSel == 0 || m.arrowSel == 2 || m.arrowSel == 3 {
				m.arrowSel = 1
			}

		case "right", "l":
			if m.focusArea == 0 {
				m.moveRight()
			} else if m.arrowSel == 0 || m.arrowSel == 1 || m.arrowSel == 2 {
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

func (m model) rowWidth(keys []keyDef) int {
	w := 0
	for _, k := range keys {
		w += k.w
	}
	return w
}

func intMax(a, b int) int {
	if a > b {
		return a
	}
	return b
}

// renderRow3Lines renders a row of keys as 3 visual lines
func (m model) renderRow3Lines(keys []keyDef, rowIdx int) [3]string {
	// Collect key blocks
	blocks := make([][3]string, len(keys))
	for col, k := range keys {
		isSel := m.focusArea == 0 && rowIdx == m.selRow && col == m.selCol
		isPrs := m.pressed[k.code]
		blocks[col] = renderKeyBlock(k, isSel, isPrs)
	}

	// Join horizontally
	var lines [3]string
	for i := 0; i < 3; i++ {
		var parts []string
		for _, b := range blocks {
			parts = append(parts, b[i])
		}
		lines[i] = strings.Join(parts, "")
	}
	return lines
}

func (m model) renderNumpadRow3Lines(keys []keyDef) [3]string {
	blocks := make([][3]string, len(keys))
	for i, k := range keys {
		isPrs := m.pressed[k.code]
		blocks[i] = renderKeyBlock(k, false, isPrs)
	}

	var lines [3]string
	for i := 0; i < 3; i++ {
		var parts []string
		for _, b := range blocks {
			parts = append(parts, b[i])
		}
		lines[i] = strings.Join(parts, "")
	}
	return lines
}

func (m model) renderArrow3Lines() [3]string {
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

	// Row 1: (gap) ▲ (gap)
	spacer := renderKeyBlock(keyDef{w: 4}, false, false)
	up := renderKeyBlock(k0, s0, p0)
	// Row 2: ◀ ▼ ▶
	left := renderKeyBlock(k1, s1, p1)
	down := renderKeyBlock(k2, s2, p2)
	right := renderKeyBlock(k3, s3, p3)

	var lines [3]string
	for i := 0; i < 3; i++ {
		line1 := spacer[i] + up[i] + spacer[i]
		line2 := left[i] + down[i] + right[i]
		if i == 0 {
			lines[i] = line1 + "\n" + line2
		} else {
			lines[i] = line1 + "\n" + line2
		}
	}
	return lines
}

func (m model) View() string {
	var b strings.Builder

	b.WriteString(titleStyle.Render("108-Key Keyboard Layout"))
	b.WriteString("\n\n")

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

	// Find max width of main keyboard rows
	targetW := 0
	for rowIdx := 0; rowIdx < len(m.keys); rowIdx++ {
		targetW = intMax(targetW, m.rowWidth(m.keys[rowIdx]))
	}

	// Render each row as 3 visual lines
	for rowIdx := 0; rowIdx < len(m.keys); rowIdx++ {
		// Main section: 3 lines
		mainLines := m.renderRow3Lines(m.keys[rowIdx], rowIdx)

		// Pad main section to targetW
		for i := 0; i < 3; i++ {
			mainLines[i] = padRight(mainLines[i], targetW)
		}

		// Numpad section: 3 lines
		var numpadLines [3]string
		if rowIdx < len(m.numpad) {
			numpadLines = m.renderNumpadRow3Lines(m.numpad[rowIdx])
		} else {
			nw := 0
			if rowIdx < len(m.numpad) {
				for _, k := range m.numpad[rowIdx] {
					nw += k.w
				}
			}
			// Use the numpad width from the row that has the most keys
			nw = 21 // 4 keys * 5 + one extra
			for i := 0; i < 3; i++ {
				numpadLines[i] = strings.Repeat(" ", nw)
			}
		}

		// Arrow block: 3 lines (only on rows 5 and 6)
		var arrowLines [3]string
		hasArrow := rowIdx == 5 || rowIdx == 6
		if hasArrow {
			allArrow := m.renderArrow3Lines()
			// Parse the 2-line arrow block
			arrowParts := strings.Split(allArrow[0], "\n")
			if rowIdx == 5 && len(arrowParts) > 0 {
				for i := 0; i < 3; i++ {
					arrowLines[i] = arrowParts[0]
				}
			} else if rowIdx == 6 && len(arrowParts) > 1 {
				for i := 0; i < 3; i++ {
					arrowLines[i] = arrowParts[1]
				}
			}
		}

		// Combine: "  " + main + "  " + numpad + "  " + arrow
		for i := 0; i < 3; i++ {
			b.WriteString("  ")
			b.WriteString(mainLines[i])
			b.WriteString("  ")
			b.WriteString(numpadLines[i])
			if hasArrow {
				b.WriteString("  ")
				b.WriteString(arrowLines[i])
			}
			b.WriteString("\n")
		}
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
