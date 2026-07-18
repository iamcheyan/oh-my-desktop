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

type status map[string]string

type statusMsg struct {
	values status
	err    error
}

type themesMsg struct {
	themes []themeEntry
	err    error
}

type actionMsg struct {
	action string
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

func buttonText(key, label string) string {
	icon := actionIcon(key)
	if icon == "" {
		return mnemonicLabel(key, label)
	}
	return icon + "  " + mnemonicLabel(key, label)
}

func mnemonicLabel(key, label string) string {
	pal := defaultMnemonicPalette()
	key = strings.TrimSpace(key)
	if key == "" {
		return label
	}
	if len([]rune(key)) == 1 {
		return underlineFirstMatch(label, key, pal.accent)
	}
	return lipgloss.NewStyle().Foreground(pal.accent).Underline(true).Render(key) + " " + label
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

func defaultMnemonicPalette() palette {
	return palette{accent: ui.Accent}
}

func helpKey(key, label string) string {
	return lipgloss.NewStyle().Foreground(ui.Accent).Underline(true).Render(key) + " " + label
}

type Model struct {
	backend  backend.Backend
	status   status
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
			if !m.busy {
				m.busy = true
				return m, m.runAction("wallpaper-next")
			}
		case "x":
			if !m.busy {
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
			if !m.busy {
				m.busy = true
				return m, m.interval(-300)
			}
		case "]", "=":
			if !m.busy {
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
	case statusMsg:
		if msg.err != nil {
			m.err = msg.err.Error()
		} else {
			m.status = msg.values
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
	case actionMsg:
		m.busy = false
		m.applying = ""
		if msg.err != nil {
			m.err = msg.err.Error()
			m.message = "Theme apply failed"
		} else {
			m.message = themeActionMessage(msg.action)
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
		screenPaddingX = 4
		screenPaddingY = 2
		panelBorderW   = 2
		panelBorderH   = 2
		panelPadW      = 4
		panelPadH      = 2
		fixedRows      = 2
	)

	pal := m.palette()
	panelInnerW := width - screenPaddingX - panelBorderW - panelPadW
	if panelInnerW < 14 {
		panelInnerW = 14
	}
	panelInnerH := height - screenPaddingY - fixedRows - panelBorderH - panelPadH
	if panelInnerH < 14 {
		panelInnerH = 14
	}
	panelBoxW := panelInnerW + panelPadW
	panelBoxH := panelInnerH + panelPadH

	titleStyle := lipgloss.NewStyle().Foreground(pal.text).Bold(true)
	mutedStyle := lipgloss.NewStyle().Foreground(pal.muted)
	header := titleStyle.Render("Personalization") + " " + mutedStyle.Render(">") + " " + titleStyle.Render("Background")
	if m.busy {
		header += " " + lipgloss.NewStyle().Foreground(pal.accent).Render("working...")
	}
	if m.err != "" {
		header += " " + ui.DangerText.Render(m.err)
	}
	if m.message != "" && !m.busy {
		header += " " + lipgloss.NewStyle().Foreground(pal.accent).Render(m.message)
	}

	panelStyle := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(pal.line).
		Background(pal.panel).
		Padding(1, 2)
	content := panelStyle.Width(panelBoxW).Height(panelBoxH).Render(
		ui.PreserveBackground(ui.FitBlock(m.contentView(panelInnerW, panelInnerH), panelInnerW, panelInnerH), pal.panel),
	)

	help := lipgloss.NewStyle().Foreground(pal.muted).Render(strings.Join([]string{
		helpKey("arrows", "theme"),
		helpKey("enter", "apply"),
		helpKey("f", "file"),
		helpKey("d", "folder"),
		helpKey("w", "next"),
		helpKey("x", "stop"),
		helpKey("[/]", "interval"),
		helpKey("1/2/3", "effects"),
		helpKey("r", "refresh"),
		helpKey("q", "quit"),
	}, "  "))
	if m.applying != "" {
		help = lipgloss.NewStyle().Foreground(pal.accent).Render("applying " + m.applying + "…")
	}

	return lipgloss.NewStyle().Background(pal.background).Foreground(pal.text).Padding(1, 2).Render(
		lipgloss.JoinVertical(lipgloss.Left,
			header,
			content,
			help,
		),
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
	previewHeight := 10
	infoWidth := width - previewWidth - 3
	mode := m.value("wallpaper.mode", "file")
	if infoWidth < 44 {
		previewWidth = min(width, 22)
		return strings.Join([]string{
			m.wallpaperPreview(previewWidth, previewHeight),
			m.row("Wallpaper", shortPath(m.value("wallpaper.current", "-")), width),
			m.row("Mode", m.value("wallpaper.mode", "file"), width),
			m.row("Interval", intervalLabel(m.value("wallpaper.interval", "1800")), width),
			lipgloss.JoinHorizontal(lipgloss.Top,
				m.button(buttonText("f", "File"), mode == "file"),
				m.button(buttonText("d", "Folder"), mode == "folder"),
			),
			lipgloss.JoinHorizontal(lipgloss.Top,
				m.button(buttonText("w", "Next"), false),
				m.button(buttonText("x", "Stop"), false),
				m.effectSelect(),
			),
		}, "\n")
	}

	pal := m.palette()
	infoLines := []string{
		lipgloss.NewStyle().Foreground(pal.text).Bold(true).Render("Wallpaper"),
		lipgloss.NewStyle().Foreground(pal.muted).Render(ui.TruncateStyled("Current desktop background and rotation.", infoWidth)),
		"",
		m.row("Mode", m.value("wallpaper.mode", "file"), infoWidth),
		m.row("Current", shortPath(m.value("wallpaper.current", "-")), infoWidth),
		m.row("Images", m.value("wallpaper.imageCount", "0"), infoWidth),
		m.row("Interval", intervalLabel(m.value("wallpaper.interval", "1800")), infoWidth),
		"",
		lipgloss.JoinHorizontal(lipgloss.Top,
			m.button(buttonText("f", "File"), mode == "file"),
			m.button(buttonText("d", "Folder"), mode == "folder"),
			m.button(buttonText("w", "Next"), false),
			m.button(buttonText("x", "Stop"), false),
			m.effectSelect(),
		),
	}
	info := strings.Join(infoLines, "\n")
	return lipgloss.JoinHorizontal(lipgloss.Top,
		m.wallpaperPreview(previewWidth, previewHeight),
		"   ",
		info,
	)
}

func (m Model) wallpaperPreview(width, height int) string {
	width = max(22, width)
	height = max(6, height)
	innerW := max(14, width-4)
	innerH := max(4, height-2)
	pal := m.palette()
	imageView := renderImagePreview(expandPath(m.value("wallpaper.current", "")), innerW, innerH)
	if imageView == "" {
		imageView = m.previewPlaceholder("Wallpaper", shortPath(m.value("wallpaper.current", "-")), innerW, innerH)
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

func (m Model) effectSelect() string {
	pal := m.palette()
	label := effectLabel(m.value("effects.mode", "balanced"))
	text := lipgloss.NewStyle().Foreground(pal.muted).Render("Effects ") +
		lipgloss.NewStyle().Foreground(pal.accent).Underline(true).Render("1/2/3") +
		" " + label + " ▾"
	return lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(pal.line).
		Background(pal.panel).
		Foreground(pal.text).
		Padding(0, 1).
		Render(text)
}

func (m Model) fetchStatus() tea.Cmd {
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-theme", "appearance-status")
		if result.Err != nil {
			return statusMsg{err: result.Err}
		}
		return statusMsg{values: backend.ParseKV(result.Lines)}
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
		return actionMsg{action: "apply " + slug, err: result.Err}
	}
}

func (m Model) runAction(action string) tea.Cmd {
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-theme", action)
		return actionMsg{action: action, err: result.Err}
	}
}

func (m Model) effects(mode string) tea.Cmd {
	return func() tea.Msg {
		result := m.backend.Run("omd-settings-theme", "effects", mode)
		return actionMsg{action: "effects " + mode, err: result.Err}
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
		return actionMsg{action: "wallpaper-interval", err: result.Err}
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

func (m Model) palette() palette {
	bg := ui.HexColor(m.value("background", ""))
	fg := ui.HexColor(m.value("foreground", ""))
	accent := ui.HexColor(m.value("accent", ""))
	if bg == "" {
		bg = ui.Background
	}
	if fg == "" {
		fg = ui.Text
	}
	if accent == "" {
		accent = ui.Accent
	}
	return palette{
		background: bg,
		panel:      blend(bg, fg, 0.08),
		panelSoft:  blend(bg, fg, 0.14),
		line:       blend(bg, fg, 0.28),
		text:       fg,
		muted:      blend(bg, fg, 0.68),
		accent:     accent,
	}
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
	return style.Render(text)
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
	if m.status == nil {
		return fallback
	}
	if v := m.status[key]; v != "" {
		return v
	}
	return fallback
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

func shortPath(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return "-"
	}
	parts := strings.Split(s, "/")
	if len(parts) <= 3 {
		return s
	}
	return "…/" + strings.Join(parts[len(parts)-2:], "/")
}
