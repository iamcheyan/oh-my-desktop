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

	keyNormal = lipgloss.NewStyle().
			Background(lipgloss.Color("#2b2b2b")).
			Foreground(lipgloss.Color("#eeeeee")).
			Border(lipgloss.NormalBorder()).
			BorderForeground(lipgloss.Color("#555555")).
			Align(lipgloss.Center)

	keySelected = lipgloss.NewStyle().
			Background(lipgloss.Color("#7D56F4")).
			Foreground(lipgloss.Color("#FFFFFF")).
			Border(lipgloss.NormalBorder()).
			BorderForeground(lipgloss.Color("#FFFFFF")).
			Bold(true).
			Align(lipgloss.Center)

	keyPressed = lipgloss.NewStyle().
			Background(lipgloss.Color("#FF6B6B")).
			Foreground(lipgloss.Color("#FFFFFF")).
			Border(lipgloss.NormalBorder()).
			BorderForeground(lipgloss.Color("#FF6B6B")).
			Bold(true).
			Align(lipgloss.Center)

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

type model struct {
	keys      [][]keyDef
	selRow    int
	selCol    int
	pressed   map[string]bool
	keyCode   string
	width     int
	height    int
	arrowKeys []keyDef
	arrowSel  int
	focusArea int // 0=main, 1=arrows
}

func buildKeyboard() ([][]keyDef, []keyDef) {
	mainKeys := [][]keyDef{
		// Row 0: Esc + F1-F12 + PrtSc/ScrLk/Pause + Ins/Home/PgUp/Del/End/PgDn
		{
			k("Esc", 3, "escape"),
			k("F1", 3, "F1"), k("F2", 3, "F2"), k("F3", 3, "F3"), k("F4", 3, "F4"),
			k("", 1, ""),
			k("F5", 3, "F5"), k("F6", 3, "F6"), k("F7", 3, "F7"), k("F8", 3, "F8"),
			k("", 1, ""),
			k("F9", 3, "F9"), k("F10", 3, "F10"), k("F11", 3, "F11"), k("F12", 3, "F12"),
			k("", 1, ""),
			k("PrtSc", 4, "Print"), k("ScrLk", 4, "ScrollLock"), k("Pause", 4, "Pause"),
			k("", 1, ""),
			k("Ins", 3, "Insert"), k("Hom", 3, "Home"), k("PgU", 3, "PageUp"),
			k("Del", 3, "Delete"), k("End", 3, "End"), k("PgD", 3, "PageDown"),
		},
		// Row 1: ` 1-9 0 - = BkSp | NumLk / * -
		{
			k("`", 3, "`"), k("1", 3, "1"), k("2", 3, "2"), k("3", 3, "3"),
			k("4", 3, "4"), k("5", 3, "5"), k("6", 3, "6"), k("7", 3, "7"),
			k("8", 3, "8"), k("9", 3, "9"), k("0", 3, "0"), k("-", 3, "-"),
			k("=", 3, "="), k("BkSp", 6, "backspace"),
			k("", 1, ""),
			k("NumLk", 5, "NumLock"), k("/", 3, "NumpadDivide"),
			k("*", 3, "NumpadMultiply"), k("-", 3, "NumpadSubtract"),
		},
		// Row 2: Tab Q-P [ ] \ | 7 8 9 +
		{
			k("Tab", 5, "tab"),
			k("Q", 3, "q"), k("W", 3, "w"), k("E", 3, "e"), k("R", 3, "r"),
			k("T", 3, "t"), k("Y", 3, "y"), k("U", 3, "u"), k("I", 3, "i"),
			k("O", 3, "o"), k("P", 3, "p"),
			k("[", 3, "["), k("]", 3, "]"), k("\\", 5, "\\"),
			k("", 1, ""),
			k("7", 3, "Numpad7"), k("8", 3, "Numpad8"), k("9", 3, "Numpad9"),
			k("+", 3, "NumpadAdd"),
		},
		// Row 3: Caps A-L ; ' Enter | 4 5 6
		{
			k("Caps", 6, "capslock"),
			k("A", 3, "a"), k("S", 3, "s"), k("D", 3, "d"), k("F", 3, "f"),
			k("G", 3, "g"), k("H", 3, "h"), k("J", 3, "j"), k("K", 3, "k"),
			k("L", 3, "l"),
			k(";", 3, ";"), k("'", 3, "'"), k("Enter", 6, "enter"),
			k("", 1, ""),
			k("4", 3, "Numpad4"), k("5", 3, "Numpad5"), k("6", 3, "Numpad6"),
		},
		// Row 4: Shift Z-M , . / Shift | 1 2 3 Ent
		{
			k("Shift", 8, "shift"),
			k("Z", 3, "z"), k("X", 3, "x"), k("C", 3, "c"), k("V", 3, "v"),
			k("B", 3, "b"), k("N", 3, "n"), k("M", 3, "m"),
			k(",", 3, ","), k(".", 3, "."), k("/", 3, "/"),
			k("Shift", 8, "shift"),
			k("", 1, ""),
			k("1", 3, "Numpad1"), k("2", 3, "Numpad2"), k("3", 3, "Numpad3"),
			k("Ent", 3, "NumpadEnter"),
		},
		// Row 5: Ctrl Win Alt SPC Alt Win Ctrl | 0 Ins Del
		{
			k("Ctrl", 5, "ctrl"),
			k("Win", 4, "Meta"),
			k("Alt", 4, "alt"),
			k("", 22, "Space"),
			k("Alt", 4, "alt"),
			k("Win", 4, "Meta"),
			k("Fn", 3, ""),
			k("Ctrl", 5, "ctrl"),
			k("", 1, ""),
			k("0", 6, "Numpad0"), k(".", 3, "NumpadDecimal"),
		},
	}

	arrowKeys := []keyDef{
		k("", 2, ""), k("▲", 3, "Up"), k("", 2, ""),
		k("◀", 3, "Left"), k("▼", 3, "Down"), k("▶", 3, "Right"),
	}

	return mainKeys, arrowKeys
}

func initialModel() model {
	mainKeys, arrowKeys := buildKeyboard()
	return model{
		keys:      mainKeys,
		selRow:    0,
		selCol:    2,
		pressed:   make(map[string]bool),
		arrowKeys: arrowKeys,
		arrowSel:  1,
		focusArea: 0,
	}
}

func (m model) Init() tea.Cmd {
	return nil
}

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
			} else if m.arrowSel == 3 || m.arrowSel == 4 || m.arrowSel == 5 {
				m.arrowSel = 1 // up
			}

		case "down", "j":
			if m.focusArea == 0 {
				m.moveDown()
			} else if m.arrowSel == 0 || m.arrowSel == 1 || m.arrowSel == 2 {
				m.arrowSel = 4 // down
			}

		case "left", "h":
			if m.focusArea == 0 {
				m.moveLeft()
			} else if m.arrowSel == 1 || m.arrowSel == 4 {
				m.arrowSel = 3 // left
			} else if m.arrowSel == 5 {
				m.arrowSel = 4 // right -> down
			}

		case "right", "l":
			if m.focusArea == 0 {
				m.moveRight()
			} else if m.arrowSel == 1 || m.arrowSel == 4 {
				m.arrowSel = 5 // right
			} else if m.arrowSel == 3 {
				m.arrowSel = 4 // left -> down
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
		if m.colInRange(r, m.selCol) {
			m.selRow = r
			return
		}
	}
}

func (m *model) moveDown() {
	for r := m.selRow + 1; r < len(m.keys); r++ {
		if m.colInRange(r, m.selCol) {
			m.selRow = r
			return
		}
	}
}

func (m *model) moveLeft() {
	for c := m.selCol - 1; c >= 0; c-- {
		if c < len(m.keys[m.selRow]) && m.keys[m.selRow][c].label != "" {
			m.selCol = c
			return
		}
	}
}

func (m *model) moveRight() {
	for c := m.selCol + 1; c < len(m.keys[m.selRow]); c++ {
		if m.keys[m.selRow][c].label != "" {
			m.selCol = c
			return
		}
	}
}

func (m model) colInRange(row, col int) bool {
	if row < 0 || row >= len(m.keys) {
		return false
	}
	if col < 0 || col >= len(m.keys[row]) {
		return false
	}
	return m.keys[row][col].label != ""
}

func (m *model) toggleKey() {
	key := m.keys[m.selRow][m.selCol]
	if key.label == "" || key.code == "" {
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

func (m model) renderKey(k keyDef, row, col int, isSelected, isPressed bool) string {
	if k.label == "" {
		w := k.w*2 + 1
		return strings.Repeat(" ", w)
	}

	w := k.w*2 + 1
	label := k.label
	if lipgloss.Width(label) > w-2 {
		label = label[:w-2]
	}

	var s lipgloss.Style
	switch {
	case isSelected && isPressed:
		s = keyPressed.BorderForeground(lipgloss.Color("#FFD166"))
	case isSelected:
		s = keySelected
	case isPressed:
		s = keyPressed
	default:
		s = keyNormal
	}

	return s.Width(w).Height(1).Render(label)
}

func (m model) renderMainRow(row []keyDef, rowIdx int) string {
	var parts []string
	for col, k := range row {
		isSelected := m.focusArea == 0 && rowIdx == m.selRow && col == m.selCol
		isPressed := m.pressed[k.code]
		parts = append(parts, m.renderKey(k, rowIdx, col, isSelected, isPressed))
	}
	return strings.Join(parts, "")
}

func (m model) renderArrowBlock() string {
	var lines []string

	// Row 1: space ▲ space
	k0 := m.arrowKeys[0]
	k1 := m.arrowKeys[1]
	k2 := m.arrowKeys[2]
	s0 := m.focusArea == 1 && m.arrowSel == 0
	s1 := m.focusArea == 1 && m.arrowSel == 1
	s2 := m.focusArea == 1 && m.arrowSel == 2
	p0 := m.pressed[k0.code]
	p1 := m.pressed[k1.code]
	p2 := m.pressed[k2.code]
	lines = append(lines, m.renderKey(k0, 0, 0, s0, p0)+
		m.renderKey(k1, 0, 1, s1, p1)+
		m.renderKey(k2, 0, 2, s2, p2))

	// Row 2: ▼ ▼ ▶
	k3 := m.arrowKeys[3]
	k4 := m.arrowKeys[4]
	k5 := m.arrowKeys[5]
	s3 := m.focusArea == 1 && m.arrowSel == 3
	s4 := m.focusArea == 1 && m.arrowSel == 4
	s5 := m.focusArea == 1 && m.arrowSel == 5
	p3 := m.pressed[k3.code]
	p4 := m.pressed[k4.code]
	p5 := m.pressed[k5.code]
	lines = append(lines, m.renderKey(k3, 1, 0, s3, p3)+
		m.renderKey(k4, 1, 1, s4, p4)+
		m.renderKey(k5, 1, 2, s5, p5))

	return strings.Join(lines, "\n")
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
		if m.focusArea == 0 {
			selected := m.keys[m.selRow][m.selCol]
			if selected.code != "" {
				keyCodeLine += "Key: " + lipgloss.NewStyle().Foreground(lipgloss.Color("#626262")).Render(selected.code)
			}
		} else {
			selected := m.arrowKeys[m.arrowSel]
			if selected.code != "" {
				keyCodeLine += "Key: " + lipgloss.NewStyle().Foreground(lipgloss.Color("#626262")).Render(selected.code)
			}
		}
	}
	b.WriteString(keyCodeLine)
	b.WriteString("\n\n")

	// Render main keyboard rows (only first 6 rows)
	for rowIdx := 0; rowIdx < 6 && rowIdx < len(m.keys); rowIdx++ {
		b.WriteString("  ")
		b.WriteString(m.renderMainRow(m.keys[rowIdx], rowIdx))

		// Append arrow block on rows 4 and 5 (0-indexed)
		if rowIdx == 4 || rowIdx == 5 {
			arrowLines := strings.Split(m.renderArrowBlock(), "\n")
			if rowIdx-4 < len(arrowLines) {
				b.WriteString("   ")
				b.WriteString(arrowLines[rowIdx-4])
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
