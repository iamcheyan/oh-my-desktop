package main

import (
	"fmt"
	"os"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/bubbles/filepicker"
	"github.com/charmbracelet/bubbles/help"
	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/bubbles/progress"
	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/table"
	"github.com/charmbracelet/bubbles/textinput"
	"github.com/charmbracelet/bubbles/textarea"
	"github.com/charmbracelet/bubbles/viewport"
	"github.com/charmbracelet/lipgloss"
)

var (
	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#FAFAFA")).
			MarginBottom(1)

	sectionStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#7D56F4")).
			MarginTop(1).
			MarginBottom(1)

	labelStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#A0A0A0")).
			Width(20)

	descStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#666666")).
			Italic(true)

	helpStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#626262")).
			MarginTop(1)

	checkStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#04B575"))

	uncheckStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#FF6B6B"))

	toggleOnStyle = lipgloss.NewStyle().
			Background(lipgloss.Color("#7D56F4")).
			Foreground(lipgloss.Color("#FFFFFF")).
			Bold(true).
			Padding(0, 1)

	toggleOffStyle = lipgloss.NewStyle().
			Background(lipgloss.Color("#444444")).
			Foreground(lipgloss.Color("#888888")).
			Padding(0, 1)
)

type page int

const (
	pageInputs page = iota
	pageButtons
	pageSelection
	pageToggle
	pageProgress
	pageFilePicker
	pageList
	pageTable
	pageViewport
)

type item struct {
	title string
	desc  string
}

func (i item) Title() string       { return i.title }
func (i item) Description() string { return i.desc }
func (i item) FilterValue() string { return i.title }

type checkbox struct {
	label  string
	checked bool
}

func (c checkbox) View() string {
	icon := "○"
	if c.checked {
		icon = checkStyle.Render("●")
	} else {
		icon = uncheckStyle.Render("○")
	}
	return fmt.Sprintf("%s %s", icon, c.label)
}

type toggleItem struct {
	label string
	on    bool
}

func (t toggleItem) View() string {
	if t.on {
		return toggleOnStyle.Render(" ON ") + " " + t.label
	}
	return toggleOffStyle.Render(" OFF ") + " " + t.label
}

type radioGroup struct {
	title   string
	options []string
	selected int
}

func (r radioGroup) View() string {
	var b strings.Builder
	b.WriteString(r.title + "\n")
	for i, opt := range r.options {
		icon := "○"
		if i == r.selected {
			icon = checkStyle.Render("●")
		} else {
			icon = uncheckStyle.Render("○")
		}
		b.WriteString(fmt.Sprintf("  %s %s\n", icon, opt))
	}
	return b.String()
}

type model struct {
	currentPage page
	width       int
	height      int
	focused     int

	// Text inputs
	textInput      textinput.Model
	textInputPass  textinput.Model
	textInputEmail textinput.Model
	textInputNum   textinput.Model
	textArea       textarea.Model

	// Checkboxes
	checkboxes []checkbox

	// Radio
	radio radioGroup

	// Toggles
	toggles []toggleItem

	// Progress & Spinner
	progress    progress.Model
	spinner     spinner.Model
	progressPct float64

	// File picker
	filepicker filepicker.Model

	// List
	list list.Model

	// Table
	table table.Model

	// Viewport
	viewport viewport.Model

	// Help
	help help.Model

	// Keys
	keys keyMap
}

type keyMap struct {
	Quit key.Binding
}

func (k keyMap) ShortHelp() []key.Binding {
	return []key.Binding{k.Quit}
}

func (k keyMap) FullHelp() [][]key.Binding {
	return [][]key.Binding{{k.Quit}}
}

func initialModel() model {
	// Text inputs
	ti := textinput.New()
	ti.Placeholder = "Enter your name..."
	ti.Focus()
	ti.CharLimit = 50
	ti.Width = 30

	tiPass := textinput.New()
	tiPass.Placeholder = "Password..."
	tiPass.EchoMode = textinput.EchoPassword
	tiPass.EchoCharacter = '•'
	tiPass.Width = 30

	tiEmail := textinput.New()
	tiEmail.Placeholder = "user@example.com"
	tiEmail.CharLimit = 80
	tiEmail.Width = 30

	tiNum := textinput.New()
	tiNum.Placeholder = "0"
	tiNum.CharLimit = 10
	tiNum.Width = 30

	// Text area
	ta := textarea.New()
	ta.Placeholder = "Write something longer here..."
	ta.SetHeight(4)
	ta.SetWidth(40)
	ta.CharLimit = 200

	// Checkboxes
	checkboxes := []checkbox{
		{label: "Enable notifications", checked: true},
		{label: "Accept terms and conditions", checked: false},
		{label: "Subscribe to newsletter", checked: true},
		{label: "Enable dark mode", checked: false},
	}

	// Radio
	radio := radioGroup{
		title:   "Choose a color theme",
		options: []string{"Default (purple)", "Ocean (blue)", "Forest (green)", "Sunset (orange)"},
		selected: 0,
	}

	// Toggles
	toggles := []toggleItem{
		{label: "Dark Mode", on: true},
		{label: "Auto Save", on: false},
		{label: "Notifications", on: true},
		{label: "Developer Mode", on: false},
	}

	// Progress
	prog := progress.New(
		progress.WithDefaultGradient(),
		progress.WithWidth(40),
	)

	// Spinner
	sp := spinner.New()
	sp.Spinner = spinner.MiniDot
	sp.Style = lipgloss.NewStyle().Foreground(lipgloss.Color("#7D56F4"))

	// File picker
	fp := filepicker.New()
	fp.CurrentDirectory, _ = os.UserHomeDir()

	// List
	items := []list.Item{
		item{title: "Bubbletea", desc: "TUI framework based on Elm Architecture"},
		item{title: "Lipgloss", desc: "Style definitions for terminal layouts"},
		item{title: "Bubbles", desc: "Common components for Bubbletea"},
		item{title: "Huh", desc: "Interactive forms and prompts"},
		item{title: "Glow", desc: "Render Markdown in the terminal"},
		item{title: "VHS", desc: "Record terminal GIFs"},
		item{title: "Harmonica", desc: "Spring animation library"},
	}

	l := list.New(items, list.NewDefaultDelegate(), 0, 0)
	l.Title = "Charmbracelet Libraries"
	l.SetShowStatusBar(false)
	l.SetFilteringEnabled(false)

	// Table
	columns := []table.Column{
		{Title: "Name", Width: 20},
		{Title: "Version", Width: 10},
		{Title: "Stars", Width: 8},
		{Title: "Language", Width: 10},
	}

	rows := []table.Row{
		{"bubbletea", "v1.3.10", "43.8k", "Go"},
		{"lipgloss", "v1.1.0", "11.6k", "Go"},
		{"bubbles", "v1.0.0", "6.5k", "Go"},
		{"huh", "v0.6.0", "4.2k", "Go"},
		{"glow", "v2.0.0", "26.4k", "Go"},
		{"vhs", "v0.4.0", "20.4k", "Go"},
	}

	t := table.New(
		table.WithColumns(columns),
		table.WithRows(rows),
		table.WithHeight(7),
		table.WithFocused(true),
	)

	s := table.DefaultStyles()
	s.Header = s.Header.
		BorderStyle(lipgloss.NormalBorder()).
		BorderBottom(true).
		Bold(true)
	s.Selected = s.Selected.
		Foreground(lipgloss.Color("#FAFAFA")).
		Background(lipgloss.Color("#7D56F4")).
		Bold(true)
	t.SetStyles(s)

	// Viewport
	vp := viewport.New(60, 15)
	vpContent := `Welcome to the Charmbracelet Bubbles Demo!

This viewport component shows scrollable content.
You can scroll up and down with arrow keys or mouse wheel.

Features of Bubbles:
  - Text Input: Single-line input with various modes
  - Text Area: Multi-line input for longer text
  - Progress Bar: Animated progress indicators
  - Spinner: Loading animations
  - File Picker: Browse and select files
  - List: Scrollable list with selection
  - Table: Data table with columns and rows
  - Viewport: Scrollable content area
  - Help: Context-sensitive help display

Each component follows the Elm Architecture pattern:
  Model  -> Update -> View -> Render

The framework handles:
  - Terminal rendering and diffing
  - Keyboard and mouse input
  - Window resize events
  - Async commands (I/O, timers, etc.)

Try interacting with each component!
`
	vp.SetContent(vpContent)

	// Help
	h := help.New()

	// Keys
	k := keyMap{
		Quit: key.NewBinding(
			key.WithKeys("ctrl+c", "q"),
			key.WithHelp("ctrl+c/q", "quit"),
		),
	}

	return model{
		currentPage: pageInputs,
		textInput:   ti,
		textInputPass: tiPass,
		textInputEmail: tiEmail,
		textInputNum: tiNum,
		textArea:    ta,
		checkboxes:  checkboxes,
		radio:       radio,
		toggles:     toggles,
		progress:    prog,
		spinner:     sp,
		progressPct: 0,
		filepicker:  fp,
		list:        l,
		table:       t,
		viewport:    vp,
		help:        h,
		keys:        k,
	}
}

func (m model) Init() tea.Cmd {
	return tea.Batch(
		textinput.Blink,
		m.spinner.Tick,
		m.progress.SetPercent(0.65),
	)
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.list.SetWidth(msg.Width - 4)
		m.list.SetHeight(msg.Height - 6)
		m.viewport.Width = msg.Width - 4
		m.viewport.Height = msg.Height - 8
		return m, nil

	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c":
			return m, tea.Quit

		case "tab", "shift+tab":
			if m.currentPage == pageInputs {
				if msg.String() == "tab" {
					m.focused++
					if m.focused > 5 {
						m.focused = 0
					}
				} else {
					m.focused--
					if m.focused < 0 {
						m.focused = 5
					}
				}
				return m, m.updateFocus()
			}

		case "enter", " ":
			if m.currentPage == pageSelection {
				return m, m.toggleCheckbox()
			}
			if m.currentPage == pageToggle {
				return m, m.toggleSwitch()
			}

		case "up", "k":
			if m.currentPage == pageSelection {
				if m.radio.selected > 0 {
					m.radio.selected--
				}
				return m, nil
			}
			if m.currentPage == pageToggle {
				if m.focused > 0 {
					m.focused--
				}
				return m, nil
			}

		case "down", "j":
			if m.currentPage == pageSelection {
				if m.radio.selected < len(m.radio.options)-1 {
					m.radio.selected++
				}
				return m, nil
			}
			if m.currentPage == pageToggle {
				if m.focused < len(m.toggles)-1 {
					m.focused++
				}
				return m, nil
			}

		case "1":
			m.currentPage = pageInputs
			m.focused = 0
			return m, m.updateFocus()
		case "2":
			m.currentPage = pageButtons
			return m, nil
		case "3":
			m.currentPage = pageSelection
			m.focused = 0
			return m, nil
		case "4":
			m.currentPage = pageToggle
			m.focused = 0
			return m, nil
		case "5":
			m.currentPage = pageProgress
			return m, nil
		case "6":
			m.currentPage = pageFilePicker
			return m, nil
		case "7":
			m.currentPage = pageList
			return m, nil
		case "8":
			m.currentPage = pageTable
			return m, nil
		case "9":
			m.currentPage = pageViewport
			return m, nil
		}
	}

	var cmds []tea.Cmd

	switch m.currentPage {
	case pageInputs:
		var cmd tea.Cmd
		m.textInput, cmd = m.textInput.Update(msg)
		cmds = append(cmds, cmd)
		m.textInputPass, cmd = m.textInputPass.Update(msg)
		cmds = append(cmds, cmd)
		m.textInputEmail, cmd = m.textInputEmail.Update(msg)
		cmds = append(cmds, cmd)
		m.textInputNum, cmd = m.textInputNum.Update(msg)
		cmds = append(cmds, cmd)
		m.textArea, cmd = m.textArea.Update(msg)
		cmds = append(cmds, cmd)

	case pageProgress:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		cmds = append(cmds, cmd)
		pModel, pCmd := m.progress.Update(msg)
		m.progress = pModel.(progress.Model)
		cmds = append(cmds, pCmd)

	case pageFilePicker:
		var cmd tea.Cmd
		m.filepicker, cmd = m.filepicker.Update(msg)
		cmds = append(cmds, cmd)

	case pageList:
		var cmd tea.Cmd
		m.list, cmd = m.list.Update(msg)
		cmds = append(cmds, cmd)

	case pageTable:
		var cmd tea.Cmd
		m.table, cmd = m.table.Update(msg)
		cmds = append(cmds, cmd)

	case pageViewport:
		var cmd tea.Cmd
		m.viewport, cmd = m.viewport.Update(msg)
		cmds = append(cmds, cmd)
	}

	return m, tea.Batch(cmds...)
}

func (m *model) updateFocus() tea.Cmd {
	m.textInput.Blur()
	m.textInputPass.Blur()
	m.textInputEmail.Blur()
	m.textInputNum.Blur()

	switch m.focused {
	case 0:
		return m.textInput.Focus()
	case 1:
		return m.textInputPass.Focus()
	case 2:
		return m.textInputEmail.Focus()
	case 3:
		return m.textInputNum.Focus()
	case 4:
		return m.textArea.Focus()
	}
	return nil
}

func (m *model) toggleCheckbox() tea.Cmd {
	if m.focused < len(m.checkboxes) {
		m.checkboxes[m.focused].checked = !m.checkboxes[m.focused].checked
	}
	return nil
}

func (m *model) toggleSwitch() tea.Cmd {
	if m.focused < len(m.toggles) {
		m.toggles[m.focused].on = !m.toggles[m.focused].on
	}
	return nil
}

func (m model) View() string {
	var b strings.Builder

	b.WriteString(titleStyle.Render("Charmbracelet Bubbles Demo"))
	b.WriteString("\n")
	b.WriteString(helpStyle.Render("Press 1-9 to switch pages  •  Ctrl+C to quit"))
	b.WriteString("\n\n")

	switch m.currentPage {
	case pageInputs:
		b.WriteString(m.viewInputs())
	case pageButtons:
		b.WriteString(m.viewButtons())
	case pageSelection:
		b.WriteString(m.viewSelection())
	case pageToggle:
		b.WriteString(m.viewToggle())
	case pageProgress:
		b.WriteString(m.viewProgress())
	case pageFilePicker:
		b.WriteString(m.viewFilePicker())
	case pageList:
		b.WriteString(m.viewList())
	case pageTable:
		b.WriteString(m.viewTable())
	case pageViewport:
		b.WriteString(m.viewViewport())
	}

	return b.String()
}

func (m model) viewInputs() string {
	var b strings.Builder

	b.WriteString(sectionStyle.Render("1 - Text Inputs & Text Area"))
	b.WriteString("\n")

	b.WriteString(labelStyle.Render("Name"))
	b.WriteString(m.textInput.View())
	b.WriteString("\n")

	b.WriteString(labelStyle.Render("Password"))
	b.WriteString(m.textInputPass.View())
	b.WriteString("\n")

	b.WriteString(labelStyle.Render("Email"))
	b.WriteString(m.textInputEmail.View())
	b.WriteString("\n")

	b.WriteString(labelStyle.Render("Number"))
	b.WriteString(m.textInputNum.View())
	b.WriteString("\n\n")

	b.WriteString(sectionStyle.Render("Text Area"))
	b.WriteString("\n")
	b.WriteString(m.textArea.View())
	b.WriteString("\n")

	return b.String()
}

func (m model) viewButtons() string {
	var b strings.Builder

	b.WriteString(sectionStyle.Render("2 - Buttons & Status Indicators"))
	b.WriteString("\n\n")

	normalBtn := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(lipgloss.Color("#666666")).
		Foreground(lipgloss.Color("#EEEEEE")).
		Padding(0, 3).
		Render("Normal")

	primaryBtn := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(lipgloss.Color("#7D56F4")).
		Foreground(lipgloss.Color("#7D56F4")).
		Bold(true).
		Padding(0, 3).
		Render("Primary")

	dangerBtn := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(lipgloss.Color("#FF6B6B")).
		Foreground(lipgloss.Color("#FF6B6B")).
		Padding(0, 3).
		Render("Danger")

	successBtn := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(lipgloss.Color("#04B575")).
		Foreground(lipgloss.Color("#04B575")).
		Padding(0, 3).
		Render("Success")

	disabledBtn := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(lipgloss.Color("#444444")).
		Foreground(lipgloss.Color("#444444")).
		Padding(0, 3).
		Render("Disabled")

	b.WriteString("Button styles:\n\n")
	b.WriteString("  " + normalBtn + "  " + primaryBtn + "  " + dangerBtn + "\n")
	b.WriteString("  " + successBtn + "  " + disabledBtn + "\n\n")

	b.WriteString(sectionStyle.Render("Status Indicators"))
	b.WriteString("\n")
	b.WriteString("  ✓ Active    ✗ Failed    ▸ Pending    ● Running\n\n")

	b.WriteString(sectionStyle.Render("Badges / Pills"))
	b.WriteString("\n")

	pill := func(label string, color string) string {
		return lipgloss.NewStyle().
			Background(lipgloss.Color(color)).
			Foreground(lipgloss.Color("#FFFFFF")).
			Padding(0, 2).
			Bold(true).
			Render(label)
	}

	b.WriteString("  " + pill("NEW", "#7D56F4") + "  " +
		pill("HOT", "#FF6B6B") + "  " +
		pill("OK", "#04B575") + "  " +
		pill("WARN", "#FFD166") + "  " +
		pill("INFO", "#6CC6FF") + "\n\n")

	b.WriteString(sectionStyle.Render("Nerd Font Icons"))
	b.WriteString("\n")
	b.WriteString("  \uf013 Settings   \uf017 Timer   \uf0e0 Mail   \uf1eb WiFi   \uf233 Server\n")

	return b.String()
}

func (m model) viewSelection() string {
	var b strings.Builder

	b.WriteString(sectionStyle.Render("3 - Checkboxes & Radio Buttons"))
	b.WriteString("\n")
	b.WriteString(descStyle.Render("Use up/down to navigate, Enter/Space to toggle checkbox"))
	b.WriteString("\n\n")

	b.WriteString(labelStyle.Render("Checkboxes"))
	b.WriteString("\n")
	for i, cb := range m.checkboxes {
		cursor := "  "
		if i == m.focused {
			cursor = "▸ "
		}
		b.WriteString(cursor + cb.View() + "\n")
	}
	b.WriteString("\n")

	b.WriteString(m.radio.View())

	return b.String()
}

func (m model) viewToggle() string {
	var b strings.Builder

	b.WriteString(sectionStyle.Render("4 - Toggle Switches"))
	b.WriteString("\n")
	b.WriteString(descStyle.Render("Use up/down to navigate, Enter/Space to toggle"))
	b.WriteString("\n\n")

	for i, t := range m.toggles {
		cursor := "  "
		if i == m.focused {
			cursor = "▸ "
		}
		b.WriteString(cursor + t.View() + "\n")
	}

	return b.String()
}

func (m model) viewProgress() string {
	var b strings.Builder

	b.WriteString(sectionStyle.Render("5 - Progress Bar & Spinner"))
	b.WriteString("\n\n")

	b.WriteString(labelStyle.Render("Progress"))
	b.WriteString("\n  ")
	b.WriteString(m.progress.ViewAs(m.progressPct))
	b.WriteString("  " + fmt.Sprintf("%.0f%%", m.progressPct*100))
	b.WriteString("\n\n")

	b.WriteString("  Various states:\n")
	for _, pct := range []float64{0.1, 0.25, 0.5, 0.75, 1.0} {
		b.WriteString("  " + m.progress.ViewAs(pct) + "  " + fmt.Sprintf("%.0f%%", pct*100) + "\n")
	}
	b.WriteString("\n")

	b.WriteString(labelStyle.Render("Spinner"))
	b.WriteString("\n  " + m.spinner.View() + "  Loading...\n\n")

	b.WriteString("Combined:\n")
	b.WriteString("  " + m.spinner.View() + "  " + m.progress.ViewAs(m.progressPct) + "  " + fmt.Sprintf("%.0f%%", m.progressPct*100) + "\n")

	return b.String()
}

func (m model) viewFilePicker() string {
	var b strings.Builder

	b.WriteString(sectionStyle.Render("6 - File Picker"))
	b.WriteString("\n")
	b.WriteString(descStyle.Render("Navigate with arrow keys, press Enter to select"))
	b.WriteString("\n\n")
	b.WriteString(m.filepicker.View())
	return b.String()
}

func (m model) viewList() string {
	var b strings.Builder

	b.WriteString(sectionStyle.Render("7 - List"))
	b.WriteString("\n")
	b.WriteString(m.list.View())
	return b.String()
}

func (m model) viewTable() string {
	var b strings.Builder

	b.WriteString(sectionStyle.Render("8 - Table"))
	b.WriteString("\n")
	b.WriteString(descStyle.Render("Navigate with arrow keys"))
	b.WriteString("\n\n")
	b.WriteString(m.table.View())
	return b.String()
}

func (m model) viewViewport() string {
	var b strings.Builder

	b.WriteString(sectionStyle.Render("9 - Viewport (Scrollable Content)"))
	b.WriteString("\n")
	b.WriteString(descStyle.Render("Scroll with arrow keys or mouse wheel"))
	b.WriteString("\n\n")
	b.WriteString(m.viewport.View())
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
