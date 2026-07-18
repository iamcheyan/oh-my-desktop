package theme

import (
	"fmt"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"math"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	_ "golang.org/x/image/webp"

	"github.com/iamcheyan/oh-my-desktop/tui-go/internal/backend"
	"github.com/iamcheyan/oh-my-desktop/tui-go/internal/ui"
)

type themesMsg struct {
	themes []themeEntry
	err    error
}

type themeEntry struct {
	slug       string
	name       string
	current    bool
	accent     string
	background string
	foreground string
}

type palette struct {
	background lipgloss.Color
	panel      lipgloss.Color
	panelSoft  lipgloss.Color
	line       lipgloss.Color
	text       lipgloss.Color
	muted      lipgloss.Color
	accent     lipgloss.Color
}

// imagePreviewCache memoizes the decoded wallpaper preview so repeated View
// frames do not re-stat or re-decode the same file. bubbletea runs Update and
// View single-threaded, so the unsynchronized global is safe here.
var imagePreviewCache struct {
	path    string
	width   int
	height  int
	modTime int64
	size    int64
	view    string
}

// Nerd Font glyphs for the action buttons (terminal must use a patched font).
const (
	iconFile    = "\uf15b" // nf-fa-file
	iconFolder  = "\uf07b" // nf-fa-folder
	iconNext    = "\uf04e" // nf-fa-forward
	iconStop    = "\uf04d" // nf-fa-stop
	iconBolt    = "\uf0e7" // nf-fa-bolt
	iconBalance = "\uf24e" // nf-fa-balance_scale
	iconImage   = "\uf03e" // nf-fa-image
	iconApply   = "\uf00c" // nf-fa-check
	iconRefresh = "\uf021" // nf-fa-refresh
)

// actionIcon maps a button's leading key token to its Nerd Font glyph.
func actionIcon(key string) string {
	switch key {
	case "f":
		return iconFile
	case "d":
		return iconFolder
	case "w":
		return iconNext
	case "x":
		return iconStop
	case "1":
		return iconBolt
	case "2":
		return iconBalance
	case "3":
		return iconImage
	case "enter", "a":
		return iconApply
	case "r":
		return iconRefresh
	}
	return ""
}

// buttonText renders the theme button label: a Nerd Font glyph (looked up by
// the action key) plus the mnemonic. Delegates the mnemonic rendering to
// ui.ActionText so all pages share one styling path.
func buttonText(key, label string) string {
	return ui.IconButton(actionIcon(key), key, label)
}

type Model struct {
	backend  backend.Backend
	status   backend.Status
	themes   []themeEntry
	width    int
	height   int
	busy     bool
	applying string
	err      string
	message  string
	selected int
	loaded   bool
}

func New(b backend.Backend) Model {
	return Model{backend: b, selected: 0}
}

func (m Model) Init() tea.Cmd {
	return tea.Batch(m.fetchStatus(), m.fetchThemes())
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c", "esc":
			return m, tea.Quit
		case "up", "k":
			m.moveSelection(-m.gridColumnsFor(m.contentWidth()))
		case "down", "j":
			m.moveSelection(m.gridColumnsFor(m.contentWidth()))
		case "left", "h":
			m.moveSelection(-1)
		case "right", "l":
			m.moveSelection(1)
		case "r":
			return m, tea.Batch(m.fetchStatus(), m.fetchThemes())
		case "enter", "a":
			if !m.busy && m.selected < len(m.themes) {
				slug := m.themes[m.selected].slug
				m.busy = true
				m.applying = slug
				m.message = fmt.Sprintf("Applying %s…", slug)
				return m, m.apply(slug)
			}
		case "w":
			if !m.busy && m.value("wallpaper.mode", "file") == "folder" {
				m.busy = true
				return m, m.runAction("wallpaper-next")
			}
		case "x":
			if !m.busy && m.value("wallpaper.mode", "file") == "folder" {
				m.busy = true
				return m, m.runAction("wallpaper-stop")
			}
		case "f":
			if !m.busy {
				m.busy = true
				return m, m.runAction("wallpaper-pick-file")
			}
		case "d":
			if !m.busy {
				m.busy = true
				return m, m.runAction("wallpaper-pick-folder")
			}
		case "[", "-":
			if !m.busy && m.value("wallpaper.mode", "file") == "folder" {
				m.busy = true
				return m, m.interval(-300)
			}
		case "]", "=":
			if !m.busy && m.value("wallpaper.mode", "file") == "folder" {
				m.busy = true
				return m, m.interval(300)
			}
		case "1":
			if !m.busy {
				m.busy = true
				return m, m.effects("performance")
			}
		case "2":
			if !m.busy {
				m.busy = true
				return m, m.effects("balanced")
			}
		case "3":
			if !m.busy {
				m.busy = true
				return m, m.effects("visuals")
			}
		}
	case backend.StatusMsg:
		if msg.Err != nil {
			m.err = msg.Err.Error()
		} else {
			m.status = msg.Values
			m.err = ""
		}
	case themesMsg:
		if msg.err == nil {
			m.themes = msg.themes
			if !m.loaded {
				for i, theme := range m.themes {
					if theme.current {
						m.selected = i
						break
					}
				}
				m.loaded = true
			}
			// keep selection within bounds
			if m.selected >= len(m.themes) {
				m.selected = len(m.themes) - 1
			}
			if m.selected < 0 {
				m.selected = 0
			}
		}
	case backend.ActionMsg:
		m.busy = false
		m.applying = ""
		if msg.Err != nil {
			m.err = msg.Err.Error()
			m.message = "Theme apply failed"
		} else {
			m.message = themeActionMessage(msg.Action)
		}
		return m, tea.Batch(m.fetchStatus(), m.fetchThemes())
	}
	return m, nil
}

func (m Model) View() string {
	if m.width <= 0 || m.height <= 0 {
		return "Initializing..."
	}
	width := m.width
	height := m.height

	const (
		screenPaddingX = 2
		screenPaddingY = 2
	)

	pal := m.palette()
	contentW := width - screenPaddingX
	if contentW < 14 {
		contentW = 14
	}
	header := ""
	if m.busy {
		header = lipgloss.NewStyle().Foreground(pal.accent).Render("working...")
	}
	if m.err != "" {
		if header != "" {
			header += " "
		}
		header += ui.DangerText.Render(m.err)
	}
	if m.message != "" && !m.busy {
		if header != "" {
			header += " "
		}
		header += lipgloss.NewStyle().Foreground(pal.accent).Render(m.message)
	}

	fixedRows := 1
	if header != "" {
		fixedRows++
	}
	contentH := height - screenPaddingY - fixedRows
	if contentH < 14 {
		contentH = 14
	}

	content := ui.PreserveBackground(ui.FitBlock(m.contentView(contentW, contentH), contentW, contentH), pal.background)

	helpItems := []string{
		ui.HelpItem("arrows", "theme"),
		ui.HelpItem("enter", "apply"),
		ui.HelpItem("f", "file"),
		ui.HelpItem("d", "folder"),
	}
	if m.value("wallpaper.mode", "file") == "folder" {
		helpItems = append(helpItems,
			ui.HelpItem("w", "next"),
			ui.HelpItem("x", "stop"),
			ui.HelpItem("[/]", "interval"),
		)
	}
	helpItems = append(helpItems,
		ui.HelpItem("1/2/3", "effects"),
		ui.HelpItem("r", "refresh"),
		ui.HelpItem("q", "quit"),
	)
	help := lipgloss.NewStyle().Foreground(pal.muted).Render(strings.Join(helpItems, "  "))
	if m.applying != "" {
		help = lipgloss.NewStyle().Foreground(pal.accent).Render("applying " + m.applying + "…")
	}

	parts := []string{content, help}
	if header != "" {
		parts = append([]string{header}, parts...)
	}
	return lipgloss.NewStyle().Background(pal.background).Foreground(pal.text).Padding(1, 1).Render(
		lipgloss.JoinVertical(lipgloss.Left, parts...),
	)
}

func (m Model) contentView(width, height int) string {
	if m.status == nil {
		return "Loading..."
	}

	themeRows := max(1, (height-15)/5)
	lines := []string{m.heroView(width)}
	lines = append(lines, "")
	lines = append(lines, m.themeGridView(width, themeRows))
	return strings.Join(lines, "\n")
}

func (m Model) heroView(width int) string {
	previewWidth := 22
	previewHeight := 8
	mode := m.value("wallpaper.mode", "file")
	preview := m.wallpaperPreview(previewWidth, previewHeight)
	// Borders and padding make the rendered preview wider than previewWidth.
	// Measure the final block so the information column never crosses the
	// terminal boundary at fractional/HiDPI terminal sizes.
	infoWidth := width - lipgloss.Width(preview) - 3
	if infoWidth < 44 {
		return strings.Join([]string{preview, m.wallpaperControls(width, mode)}, "\n")
	}
	return lipgloss.JoinHorizontal(lipgloss.Center, preview, "   ", m.wallpaperControls(infoWidth, mode))
}

func (m Model) statusInfoText(width int) string {
	pal := m.palette()
	mode := m.value("wallpaper.mode", "file")

	currentWp := m.value("wallpaper.current", "")
	wpName := "No wallpaper set"
	if currentWp != "" {
		wpName = filepath.Base(currentWp)
	}

	modeText := "Single Image"
	if mode == "folder" {
		modeText = "Folder Rotation"
	}

	effectsText := effectLabel(m.value("effects.mode", "balanced"))

	styleTitle := lipgloss.NewStyle().Foreground(pal.accent).Bold(true)
	styleLabel := lipgloss.NewStyle().Foreground(pal.text)
	styleValue := lipgloss.NewStyle().Foreground(pal.muted)

	lines := []string{
		styleTitle.Render("STATUS"),
		styleLabel.Render("File:   ") + styleValue.Render(ui.TruncatePlain(wpName, width-10)),
		styleLabel.Render("Mode:   ") + styleValue.Render(modeText),
		styleLabel.Render("Effect: ") + styleValue.Render(effectsText),
	}

	if mode == "folder" {
		interval := intervalLabel(m.value("wallpaper.interval", "1800"))
		lines = append(lines, styleLabel.Render("Rate:   ") + styleValue.Render(interval))
	}

	return strings.Join(lines, "\n")
}

func (m Model) wallpaperControls(width int, mode string) string {
	modeButtons := lipgloss.JoinHorizontal(lipgloss.Top,
		m.button(buttonText("f", "File"), mode == "file"),
		m.button(buttonText("d", "Folder"), mode == "folder"),
	)
	
	btnLines := make([]string, 0, 3)
	if width < 60 {
		btnLines = append(btnLines, modeButtons, m.effectSelect())
	} else {
		btnLines = append(btnLines, lipgloss.JoinHorizontal(lipgloss.Top, modeButtons, "  ", m.effectSelect()))
	}
	
	if mode == "folder" {
		folderButtons := lipgloss.JoinHorizontal(lipgloss.Top,
			m.button(buttonText("w", "Next"), false),
			m.button(buttonText("x", "Stop"), false),
		)
		if width < 60 {
			btnLines = append(btnLines, folderButtons, m.intervalSelect())
		} else {
			btnLines = append(btnLines, lipgloss.JoinHorizontal(lipgloss.Top, folderButtons, "  ", m.intervalSelect()))
		}
	}
	
	buttonsBlock := strings.Join(btnLines, "\n\n")
	
	statusWidth := 28
	buttonsWidth := width - statusWidth - 4
	
	if buttonsWidth >= 24 {
		statusPart := lipgloss.NewStyle().Width(statusWidth).Render(m.statusInfoText(statusWidth))
		buttonsPart := lipgloss.NewStyle().Width(buttonsWidth).Render(buttonsBlock)
		return lipgloss.JoinHorizontal(lipgloss.Top, statusPart, "    ", buttonsPart)
	}
	
	return strings.Join([]string{m.statusInfoText(width), "", buttonsBlock}, "\n")
}

func (m Model) wallpaperPreview(width, height int) string {
	width = max(22, width)
	height = max(6, height)
	innerW := max(14, width-4)
	innerH := max(4, height-2)
	pal := m.palette()
	imageView := renderImagePreview(expandPath(m.value("wallpaper.current", "")), innerW, innerH)
	if imageView == "" {
		imageView = m.previewPlaceholder("Wallpaper", ui.ShortPath(m.value("wallpaper.current", "-")), innerW, innerH)
	}
	return lipgloss.NewStyle().
		Border(lipgloss.ThickBorder()).
		BorderForeground(pal.line).
		Background(pal.background).
		Padding(0, 1).
		Render(imageView)
}

func (m Model) themeGridView(width, maxRows int) string {
	if len(m.themes) == 0 {
		return "No themes available"
	}
	pal := m.palette()
	lines := []string{
		lipgloss.NewStyle().Foreground(pal.muted).Bold(true).Render("Themes"),
		lipgloss.NewStyle().Foreground(pal.muted).Render(ui.TruncateStyled("Choose a theme color. Enter applies the selected theme.", width)),
		"",
	}
	cols := m.gridColumnsFor(width)
	tileW := m.themeTileWidth(width, cols)
	totalRows := (len(m.themes) + cols - 1) / cols
	selectedRow := m.selected / cols
	startRow := 0
	if selectedRow >= maxRows {
		startRow = selectedRow - maxRows + 1
	}
	if startRow < 0 {
		startRow = 0
	}
	endRow := min(totalRows, startRow+maxRows)
	if startRow > 0 {
		lines = append(lines, lipgloss.NewStyle().Foreground(pal.muted).Render(fmt.Sprintf("… %d rows above", startRow)))
	}
	for row := startRow; row < endRow; row++ {
		var tiles []string
		for col := 0; col < cols; col++ {
			idx := row*cols + col
			if idx >= len(m.themes) {
				break
			}
			tiles = append(tiles, m.themeTile(m.themes[idx], idx, tileW))
		}
		lines = append(lines, lipgloss.JoinHorizontal(lipgloss.Top, joinWithGap(tiles, "  ")...))
	}
	if endRow < totalRows {
		lines = append(lines, lipgloss.NewStyle().Foreground(pal.muted).Render(fmt.Sprintf("… %d rows below", totalRows-endRow)))
	}
	return strings.Join(lines, "\n")
}

func (m Model) themeTile(t themeEntry, idx, width int) string {
	width = max(8, width)
	accent := ui.HexColor(t.accent)
	bg := ui.HexColor(t.background)
	fg := ui.HexColor(t.foreground)
	if accent == "" {
		accent = ui.LineSoft
	}
	if bg == "" {
		bg = ui.PanelSoft
	}
	if fg == "" {
		fg = ui.Text
	}
	marker := " "
	if t.current {
		marker = "*"
	}
	if idx == m.selected {
		marker = "▶"
	}
	top := lipgloss.NewStyle().Background(accent).Foreground(fg).Width(width).Render(" " + marker)
	sample := lipgloss.NewStyle().Background(bg).Foreground(fg).Width(width).Render("Ag")
	label := t.name
	if lipgloss.Width(label) > width {
		label = ui.TruncatePlain(label, width)
	}
	tile := strings.Join([]string{top, sample, label}, "\n")
	style := lipgloss.NewStyle().Width(width)
	if idx == m.selected {
		style = style.Border(lipgloss.NormalBorder()).BorderForeground(m.palette().accent)
	} else {
		style = style.Border(lipgloss.HiddenBorder())
	}
	return style.Render(tile)
}

// effectSelect keeps the three effect levels in one compact selector so this
// secondary setting cannot force the wallpaper controls beyond the viewport.
// The visible 1/2/3 hint documents the direct keyboard choices.
func (m Model) effectSelect() string {
	pal := m.palette()
	label := effectLabel(m.value("effects.mode", "balanced"))
	text := lipgloss.NewStyle().Foreground(pal.muted).Render("Effects ") +
		lipgloss.NewStyle().Foreground(pal.accent).Underline(true).Render("1/2/3") +
		"  " + label + " ▾"
	return m.button(text, false)
}

func (m Model) intervalSelect() string {
	pal := m.palette()
	text := lipgloss.NewStyle().Foreground(pal.muted).Render("Interval ") +
		lipgloss.NewStyle().Foreground(pal.accent).Underline(true).Render("[/]") +
		"  " + intervalLabel(m.value("wallpaper.interval", "1800"))
	return m.button(text, false)
}

func (m Model) fetchStatus() tea.Cmd {
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-theme", "appearance-status")
		if result.Err != nil {
			return backend.StatusMsg{Err: result.Err}
		}
		return backend.StatusMsg{Values: backend.ParseStatus(result.Lines)}
	}
}

func (m Model) fetchThemes() tea.Cmd {
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-theme", "list")
		if result.Err != nil {
			return themesMsg{err: result.Err}
		}
		var themes []themeEntry
		for _, line := range result.Lines {
			parts := strings.Split(line, "\t")
			if len(parts) < 2 {
				continue
			}
			e := themeEntry{
				slug:       parts[0],
				name:       parts[1],
				current:    len(parts) > 3 && parts[3] == "current",
				accent:     valAt(parts, 4),
				background: valAt(parts, 5),
				foreground: valAt(parts, 6),
			}
			themes = append(themes, e)
		}
		return themesMsg{themes: themes}
	}
}

func (m Model) apply(slug string) tea.Cmd {
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-theme", "apply", slug)
		return backend.ActionMsg{Action: "apply " + slug, Err: result.Err}
	}
}

func (m Model) runAction(action string) tea.Cmd {
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-theme", action)
		return backend.ActionMsg{Action: action, Err: result.Err}
	}
}

func (m Model) effects(mode string) tea.Cmd {
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-theme", "effects", mode)
		return backend.ActionMsg{Action: "effects " + mode, Err: result.Err}
	}
}

func (m Model) interval(delta int) tea.Cmd {
	current := atoi(m.value("wallpaper.interval", "1800"), 1800)
	next := current + delta
	if next < 300 {
		next = 300
	}
	if next > 7200 {
		next = 7200
	}
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-theme", "wallpaper-interval", fmt.Sprintf("%d", next))
		return backend.ActionMsg{Action: "wallpaper-interval", Err: result.Err}
	}
}

func (m *Model) moveSelection(delta int) {
	if len(m.themes) == 0 {
		m.selected = 0
		return
	}
	m.selected += delta
	if m.selected < 0 {
		m.selected = 0
	}
	if m.selected >= len(m.themes) {
		m.selected = len(m.themes) - 1
	}
}

func (m Model) contentWidth() int {
	return max(14, m.width-10)
}

func (m Model) gridColumnsFor(width int) int {
	if width <= 0 {
		return 1
	}
	tileW := m.themeMinTileWidth()
	gap := 2
	cols := (width + gap) / (tileW + 2 + gap)
	if cols < 1 {
		cols = 1
	}
	if cols > len(m.themes) && len(m.themes) > 0 {
		cols = len(m.themes)
	}
	if cols > 6 {
		cols = 6
	}
	return cols
}

func (m Model) themeTileWidth(width, cols int) int {
	if cols < 1 {
		cols = 1
	}
	gap := 2
	available := width - (cols-1)*gap - cols*2
	if available < cols {
		return max(8, width-2)
	}
	return max(m.themeMinTileWidth(), available/cols)
}

func (m Model) themeMinTileWidth() int {
	longest := 12
	for _, theme := range m.themes {
		if w := lipgloss.Width(theme.name); w > longest {
			longest = w
		}
	}
	return max(12, longest)
}

func joinWithGap(items []string, gap string) []string {
	if len(items) <= 1 {
		return items
	}
	out := make([]string, 0, len(items)*2-1)
	for i, item := range items {
		if i > 0 {
			out = append(out, gap)
		}
		out = append(out, item)
	}
	return out
}

func renderImagePreview(path string, width, height int) string {
	if path == "" || width <= 0 || height <= 0 {
		return ""
	}
	info, err := os.Stat(path)
	if err != nil {
		return ""
	}
	if imagePreviewCache.path == path &&
		imagePreviewCache.width == width &&
		imagePreviewCache.height == height &&
		imagePreviewCache.modTime == info.ModTime().UnixNano() &&
		imagePreviewCache.size == info.Size() {
		return imagePreviewCache.view
	}

	f, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer f.Close()

	img, _, err := image.Decode(f)
	if err != nil {
		return ""
	}

	bounds := img.Bounds()
	srcW := bounds.Dx()
	srcH := bounds.Dy()
	if srcW <= 0 || srcH <= 0 {
		return ""
	}

	sampleW := width
	sampleH := height * 2
	scale := math.Max(float64(sampleW)/float64(srcW), float64(sampleH)/float64(srcH))
	cropW := float64(sampleW) / scale
	cropH := float64(sampleH) / scale
	offsetX := (float64(srcW) - cropW) / 2
	offsetY := (float64(srcH) - cropH) / 2

	lines := make([]string, 0, height)
	for row := 0; row < height; row++ {
		var b strings.Builder
		for col := 0; col < width; col++ {
			top := sampleImageColor(img, bounds.Min.X, bounds.Min.Y, offsetX, offsetY, cropW, cropH, col, row*2, sampleW, sampleH)
			bottom := sampleImageColor(img, bounds.Min.X, bounds.Min.Y, offsetX, offsetY, cropW, cropH, col, row*2+1, sampleW, sampleH)
			b.WriteString(lipgloss.NewStyle().Foreground(top).Background(bottom).Render("▀"))
		}
		lines = append(lines, b.String())
	}
	view := strings.Join(lines, "\n")
	imagePreviewCache.path = path
	imagePreviewCache.width = width
	imagePreviewCache.height = height
	imagePreviewCache.modTime = info.ModTime().UnixNano()
	imagePreviewCache.size = info.Size()
	imagePreviewCache.view = view
	return view
}

func sampleImageColor(img image.Image, minX, minY int, offsetX, offsetY, cropW, cropH float64, x, y, outW, outH int) lipgloss.Color {
	srcX := int(offsetX + (float64(x)+0.5)*cropW/float64(outW))
	srcY := int(offsetY + (float64(y)+0.5)*cropH/float64(outH))
	bounds := img.Bounds()
	if srcX < 0 {
		srcX = 0
	}
	if srcY < 0 {
		srcY = 0
	}
	if srcX >= bounds.Dx() {
		srcX = bounds.Dx() - 1
	}
	if srcY >= bounds.Dy() {
		srcY = bounds.Dy() - 1
	}
	r, g, b, _ := img.At(minX+srcX, minY+srcY).RGBA()
	return lipgloss.Color(fmt.Sprintf("#%02x%02x%02x", uint8(r>>8), uint8(g>>8), uint8(b>>8)))
}

func (m Model) previewPlaceholder(title, subtitle string, width, height int) string {
	pal := m.palette()
	width = max(10, width)
	height = max(4, height)
	lines := make([]string, 0, height)
	lines = append(lines, lipgloss.NewStyle().Background(pal.line).Width(width).Render(" "))
	lines = append(lines, lipgloss.NewStyle().Background(pal.background).Foreground(pal.text).Width(width).Render(" "+ui.TruncatePlain(title, max(1, width-2))))
	lines = append(lines, lipgloss.NewStyle().Background(pal.background).Foreground(pal.muted).Width(width).Render(" "+ui.TruncatePlain(subtitle, max(1, width-2))))
	for len(lines) < height-1 {
		lines = append(lines, lipgloss.NewStyle().Background(pal.background).Width(width).Render(" "))
	}
	lines = append(lines, lipgloss.NewStyle().Foreground(pal.line).Width(width).Align(lipgloss.Center).Render("──────"))
	return strings.Join(lines, "\n")
}

func expandPath(path string) string {
	path = strings.TrimSpace(path)
	if path == "" {
		return ""
	}
	if strings.HasPrefix(path, "~/") {
		if home, err := os.UserHomeDir(); err == nil {
			return filepath.Join(home, strings.TrimPrefix(path, "~/"))
		}
	}
	return path
}

// paletteCache memoizes the derived palette keyed by the raw color triple so
// repeated palette() calls within one View frame (and across frames when the
// theme has not changed) do not re-run blend/rgb math. Cleared on status msg.
var paletteCache struct {
	bg, fg, accent string
	pal            palette
}

func (m Model) palette() palette {
	bg := m.value("background", "")
	fg := m.value("foreground", "")
	accent := m.value("accent", "")
	if paletteCache.bg == bg && paletteCache.fg == fg && paletteCache.accent == accent {
		return paletteCache.pal
	}
	bgC := ui.HexColor(bg)
	fgC := ui.HexColor(fg)
	accentC := ui.HexColor(accent)
	if bgC == "" {
		bgC = ui.Background
	}
	if fgC == "" {
		fgC = ui.Text
	}
	if accentC == "" {
		accentC = ui.Accent
	}
	pal := palette{
		background: bgC,
		panel:      blend(bgC, fgC, 0.08),
		panelSoft:  blend(bgC, fgC, 0.14),
		line:       blend(bgC, fgC, 0.28),
		text:       fgC,
		muted:      blend(bgC, fgC, 0.68),
		accent:     accentC,
	}
	paletteCache = struct {
		bg, fg, accent string
		pal            palette
	}{bg, fg, accent, pal}
	return pal
}

func (m Model) row(label, value string, width int) string {
	pal := m.palette()
	if width < 10 {
		width = 10
	}
	labelWidth := min(18, max(5, width/3))
	valueWidth := width - labelWidth - 1
	if valueWidth < 4 {
		valueWidth = 4
		labelWidth = max(4, width-valueWidth-1)
	}
	label = ui.TruncatePlain(label, labelWidth)
	value = ui.TruncatePlain(value, valueWidth)
	left := lipgloss.NewStyle().Foreground(pal.text).Width(labelWidth).Render(label)
	right := lipgloss.NewStyle().Foreground(pal.muted).Width(valueWidth).Align(lipgloss.Right).Render(value)
	return left + " " + right
}

func (m Model) button(text string, active bool) string {
	pal := m.palette()
	style := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(pal.line).
		Background(pal.panel).
		Foreground(pal.text).
		Padding(0, 1).
		MarginRight(1)
	if active {
		style = style.BorderForeground(pal.accent).Foreground(pal.accent).Bold(true)
	}
	// PreserveBackground stops ANSI resets inside the mnemonic/icon from
	// leaking and turning the panel background default (see commit 1a7e819).
	return style.Render(ui.PreserveBackground(text, pal.panel))
}

func blend(a, b lipgloss.Color, amount float64) lipgloss.Color {
	ar, ag, ab, okA := rgb(a)
	br, bg, bb, okB := rgb(b)
	if !okA || !okB {
		return ui.Panel
	}
	if amount < 0 {
		amount = 0
	}
	if amount > 1 {
		amount = 1
	}
	r := int(float64(ar)*(1-amount) + float64(br)*amount)
	g := int(float64(ag)*(1-amount) + float64(bg)*amount)
	bl := int(float64(ab)*(1-amount) + float64(bb)*amount)
	return lipgloss.Color(fmt.Sprintf("#%02x%02x%02x", r, g, bl))
}

func rgb(c lipgloss.Color) (int, int, int, bool) {
	s := strings.TrimPrefix(strings.TrimSpace(string(c)), "#")
	if len(s) != 6 {
		return 0, 0, 0, false
	}
	r, errR := strconv.ParseInt(s[0:2], 16, 0)
	g, errG := strconv.ParseInt(s[2:4], 16, 0)
	b, errB := strconv.ParseInt(s[4:6], 16, 0)
	if errR != nil || errG != nil || errB != nil {
		return 0, 0, 0, false
	}
	return int(r), int(g), int(b), true
}

func (m Model) value(key, fallback string) string {
	return m.status.Value(key, fallback)
}

func (m Model) bool(key string) bool {
	return m.status.Bool(key)
}

func valAt(parts []string, idx int) string {
	if idx < len(parts) {
		return parts[idx]
	}
	return ""
}

func themeActionMessage(action string) string {
	switch {
	case strings.HasPrefix(action, "apply "):
		return "Theme applied"
	case action == "wallpaper-next":
		return "Wallpaper changed"
	case action == "wallpaper-stop":
		return "Wallpaper rotation stopped"
	case action == "wallpaper-pick-file":
		return "Wallpaper selected"
	case action == "wallpaper-pick-folder":
		return "Wallpaper folder selected"
	case strings.HasPrefix(action, "wallpaper-interval "):
		return "Wallpaper interval updated"
	case strings.HasPrefix(action, "effects "):
		return "Window effects updated"
	default:
		return "Done"
	}
}

func atoi(s string, fallback int) int {
	var n int
	if _, err := fmt.Sscanf(strings.TrimSpace(s), "%d", &n); err != nil {
		return fallback
	}
	return n
}

func intervalLabel(s string) string {
	sec := atoi(s, 1800)
	if sec >= 3600 {
		return fmt.Sprintf("%dh", sec/3600)
	}
	if sec >= 60 {
		return fmt.Sprintf("%dm", sec/60)
	}
	return fmt.Sprintf("%ds", sec)
}

func effectLabel(mode string) string {
	switch mode {
	case "performance":
		return "Performance"
	case "visuals":
		return "Visuals"
	default:
		return "Balanced"
	}
}
