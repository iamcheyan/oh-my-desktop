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
	keys       [][]keyDef
	selRow     int
	selCol     int
	pressed    map[string]bool
	keyCode    string
	width      int
	height     int
	scrollOff  int
}

func buildKeyboard() [][]keyDef {
	return [][]keyDef{
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
		// Row 6: Arrow keys (under PgUp/PgDn cluster)
		{
			k("", 1, ""), k("", 1, ""), k("", 1, ""), k("", 1, ""),
			k("", 1, ""), k("", 1, ""), k("", 1, ""), k("", 1, ""),
			k("", 1, ""), k("", 1, ""), k("", 1, ""), k("", 1, ""),
			k("", 1, ""), k("", 1, ""),
			k("", 1, ""),
			k("", 1, ""), k("", 1, ""), k("", 1, ""),
			k("", 1, ""),
			k("", 2, ""), k("▲", 3, "Up"), k("", 2, ""),
			k("", 1, ""),
			k("0", 6, ""), k(".", 3, ""),
		},
		// Row 7: Arrow keys continued
		{
			k("", 1, ""), k("", 1, ""), k("", 1, ""), k("", 1, ""),
			k("", 1, ""), k("", 1, ""), k("", 1, ""), k("", 1, ""),
			k("", 1, ""), k("", 1, ""), k("", 1, ""), k("", 1, ""),
			k("", 1, ""), k("", 1, ""),
			k("", 1, ""),
			k("", 1, ""), k("", 1, ""), k("", 1, ""),
			k("", 1, ""),
			k("◀", 3, "Left"), k("▼", 3, "Down"), k("▶", 3, "Right"),
			k("", 1, ""),
			k("", 6, ""), k("", 3, ""),
		},
	}
}

func initialModel() model {
	return model{
		keys:    buildKeyboard(),
		selRow:  0,
		selCol:  2,
		pressed: make(map[string]bool),
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

		case "up", "k":
			m.moveUp()

		case "down", "j":
			m.moveDown()

		case "left", "h":
			m.moveLeft()

		case "right", "l":
			m.moveRight()

		case "enter", " ":
			m.toggleKey()
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

func (m model) renderKey(k keyDef, row, col int) string {
	if k.label == "" {
		return ""
	}

	w := k.w*2 + 1
	label := k.label
	if lipgloss.Width(label) > w-2 {
		label = label[:w-2]
	}

	pressed := m.pressed[k.code]
	selected := row == m.selRow && col == m.selCol

	var s lipgloss.Style
	switch {
	case selected && pressed:
		s = keyPressed.BorderForeground(lipgloss.Color("#FFD166"))
	case selected:
		s = keySelected
	case pressed:
		s = keyPressed
	default:
		s = keyNormal
	}

	return s.Width(w).Height(1).Render(label)
}

func (m model) renderRow(row []keyDef, rowIdx int) string {
	var parts []string
	for col, k := range row {
		rendered := m.renderKey(k, rowIdx, col)
		if rendered != "" {
			parts = append(parts, rendered)
		} else if k.label == "" && k.w <= 1 {
			parts = append(parts, strings.Repeat(" ", 2))
		} else if k.w > 1 {
			parts = append(parts, strings.Repeat(" ", k.w*2+1))
		}
	}
	return strings.Join(parts, "")
}

func (m model) View() string {
	var b strings.Builder

	b.WriteString(titleStyle.Render("108-Key Keyboard Layout"))
	b.WriteString("\n")

	// Key code display
	keyCodeLine := "  Press: "
	if m.keyCode != "" {
		keyCodeLine += keyInfoStyle.Render(m.keyCode)
	} else {
		selected := m.keys[m.selRow][m.selCol]
		if selected.code != "" {
			keyCodeLine += lipgloss.NewStyle().Foreground(lipgloss.Color("#626262")).Render(selected.code)
		}
	}
	b.WriteString(keyCodeLine)
	b.WriteString("\n\n")

	// Render keyboard
	for rowIdx, row := range m.keys {
		b.WriteString("  ")
		b.WriteString(m.renderRow(row, rowIdx))
		b.WriteString("\n")
	}

	// Group labels
	b.WriteString("\n")
	b.WriteString(groupLabelStyle.Render("  ← → ↑ ↓ move   Enter/Space toggle   q quit"))
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
