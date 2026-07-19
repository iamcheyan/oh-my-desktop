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
	"regexp"
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
	background     lipgloss.Color
	panel          lipgloss.Color
	panelSoft      lipgloss.Color
	line           lipgloss.Color
	text           lipgloss.Color
	muted          lipgloss.Color
	accent         lipgloss.Color
	colorWallpaper lipgloss.Color
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
	case tea.MouseMsg:
		if msg.Type == tea.MouseWheelUp {
			m.moveSelection(-m.gridColumnsFor(m.contentWidth()))
			return m, nil
		} else if msg.Type == tea.MouseWheelDown {
			m.moveSelection(m.gridColumnsFor(m.contentWidth()))
			return m, nil
		}
		if msg.Type == tea.MouseRelease && msg.Button == tea.MouseButtonLeft {
			clickX := msg.X
			clickY := msg.Y

			// First check top controls using plain text hit-testing
			viewStr := m.View()
			lines := strings.Split(viewStr, "\n")
			matchedControl := false
			if clickY >= 0 && clickY < len(lines) {
				var ansiRegex = regexp.MustCompile(`\x1b\[[0-9;]*[a-zA-Z]`)
				plain := ansiRegex.ReplaceAllString(lines[clickY], "")
				if clickX >= 0 && clickX < len(plain) {
					type btn struct {
						text string
						key  string
					}
					buttons := []btn{
						{"File (f)", "f"},
						{"Folder (d)", "d"},
						{"Color (c)", "c"},
						{"Next (w)", "w"},
						{"Perf (1)", "1"},
						{"Bal (2)", "2"},
						{"Vis (3)", "3"},
					}
					for _, b := range buttons {
						idx := strings.Index(plain, b.text)
						if idx >= 0 {
							if clickX >= idx-2 && clickX <= idx+len(b.text)+2 {
								matchedControl = true
								return m.handleKey(b.key)
							}
						}
					}
				}
			}

			if !matchedControl {
				// Fallback to checking theme grid click
				yOffset := 1
				if m.busy || m.err != "" || m.message != "" {
					yOffset += 1
				}
				heroHeight := 13 // 10 baseline + 3 title lines
				themeGridY := yOffset + heroHeight + 1
				cols := m.gridColumnsFor(m.contentWidth())
				tileW := m.themeTileWidth(m.contentWidth(), cols)
				gridStartY := themeGridY + 3

				selectedRow := m.selected / cols
				themeRows := max(1, (m.height-18-yOffset)/5)
				startRow := 0
				if selectedRow >= themeRows {
					startRow = selectedRow - themeRows + 1
				}
				if startRow > 0 {
					gridStartY += 1
				}

				if clickY >= gridStartY && clickY < gridStartY+themeRows*5 {
					clickRow := (clickY - gridStartY) / 5
					clickCol := -1
					for c := 0; c < cols; c++ {
						x1 := 1 + c*(tileW+4)
						x2 := x1 + tileW + 2
						if clickX >= x1 && clickX < x2 {
							clickCol = c
							break
						}
					}
					if clickCol >= 0 {
						themeIdx := (startRow+clickRow)*cols + clickCol
						if themeIdx >= 0 && themeIdx < len(m.themes) {
							m.selected = themeIdx
							if !m.busy {
								slug := m.themes[m.selected].slug
								m.busy = true
								m.applying = slug
								m.message = fmt.Sprintf("Applying %s…", slug)
								return m, m.apply(slug)
							}
						}
					}
				}
			}
		}
	case tea.KeyMsg:
		return m.handleKey(msg.String())
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
	msg := ""
	if m.err != "" {
		msg = m.err
	} else if m.message != "" && !m.busy {
		msg = m.message
	} else if m.applying != "" {
		msg = "applying " + m.applying + "…"
	}

	return ui.RenderPage(ui.Page{
		Width:  m.width,
		Height: m.height,
		Hero: ui.Hero("Theme & Appearance", m.heroSubtitle(), ui.HeroOpts{
			Tone:    ui.ToneOK,
			Busy:    m.busy,
			Message: msg,
		}),
		Left:  m.leftColumn(),
		Right: m.rightColumn(),
		Wide:  false,
		Help:  m.helpItems(),
	})
}

func (m Model) heroSubtitle() string {
	if m.status == nil {
		return "Loading…"
	}
	currentTheme := m.value("theme.current", "Default")
	count := len(m.themes)
	mode := m.value("wallpaper.mode", "file")
	daemon := "single image"
	if mode == "folder" {
		interval := intervalLabel(m.value("wallpaper.interval", "3600"))
		daemon = fmt.Sprintf("rotating every %s", interval)
	} else if mode == "color" {
		daemon = "solid color"
	}
	return fmt.Sprintf("%s · %d themes · %s", currentTheme, count, daemon)
}

func (m Model) helpItems() []string {
	mode := m.value("wallpaper.mode", "file")
	if mode == "color" {
		return []string{
			ui.HelpItem("arrows", "theme"),
			ui.HelpItem("enter", "apply"),
			ui.HelpItem("f", "file"),
			ui.HelpItem("d", "folder"),
			ui.HelpItem("r", "refresh"),
			ui.HelpItem("q", "quit"),
		}
	}
	if mode == "folder" {
		return []string{
			ui.HelpItem("arrows", "theme"),
			ui.HelpItem("enter", "apply"),
			ui.HelpItem("f", "file"),
			ui.HelpItem("c", "color"),
			ui.HelpItem("d", "pick folder"),
			ui.HelpItem("w", "next"),
			ui.HelpItem("x", "stop"),
			ui.HelpItem("[/]", "interval"),
			ui.HelpItem("1/2/3", "effects"),
			ui.HelpItem("r", "refresh"),
			ui.HelpItem("q", "quit"),
		}
	}
	return []string{
		ui.HelpItem("arrows", "theme"),
		ui.HelpItem("enter", "apply"),
		ui.HelpItem("d", "folder"),
		ui.HelpItem("c", "color"),
		ui.HelpItem("f", "pick file"),
		ui.HelpItem("1/2/3", "effects"),
		ui.HelpItem("r", "refresh"),
		ui.HelpItem("q", "quit"),
	}
}

func (m Model) leftColumn() string {
	if m.status == nil {
		return ""
	}
	contentW := max(40, m.width-10)
	// Landscape 16:9 preview: height matches controls, width for 16:9 ratio
	previewH := 8
	previewW := 28
	controlsW := contentW - previewW - 2
	if controlsW < 20 {
		controlsW = 20
	}
	preview := m.wallpaperPreview(previewW, previewH)
	controls := m.wallpaperControls(controlsW)
	return lipgloss.JoinHorizontal(lipgloss.Top, preview, "  ", controls)
}

func (m Model) rightColumn() string {
	if m.status == nil {
		return "Loading…"
	}
	w := max(40, m.width-10)
	return m.themeGridView(w, 6)
}

func (m Model) wallpaperControls(width int) string {
	pal := m.palette()
	mode := m.value("wallpaper.mode", "file")
	effect := m.value("effects.mode", "balanced")

	modeIdx := 0
	switch mode {
	case "folder":
		modeIdx = 1
	case "color":
		modeIdx = 2
	}
	modeLine := ui.SegmentedLine("Mode", []string{"file (f)", "folder (d)", "color (c)"}, modeIdx, false)

	effectIdx := 1
	switch effect {
	case "performance":
		effectIdx = 0
	case "visuals":
		effectIdx = 2
	}
	effectLine := ui.SegmentedLine("Effect", []string{"perf (1)", "bal (2)", "vis (3)"}, effectIdx, false)

	var lines []string
	lines = append(lines, ui.SectionTitle("Settings & Status"))
	lines = append(lines, modeLine)
	lines = append(lines, effectLine)
	lines = append(lines, "")

	var actions []string
	if mode == "file" {
		actions = append(actions, ui.ActionLine("f", "Pick file", !m.busy))
	} else if mode == "folder" {
		actions = append(actions, ui.ActionLine("d", "Pick folder", !m.busy))
		actions = append(actions, ui.ActionLine("w", "Next", !m.busy))
		actions = append(actions, ui.ActionLine("x", "Stop", !m.busy))
		actions = append(actions, m.intervalSelect())
	} else {
		actions = append(actions, ui.ActionLine("c", "Solid color", !m.busy))
	}
	if len(actions) > 0 {
		lines = append(lines, strings.Join(actions, "  "))
	}

	lines = append(lines, "")
	if mode == "color" {
		lines = append(lines, ui.SectionTitle("Active Background"))
		bgHex := fmt.Sprintf("#%s", strings.TrimPrefix(string(pal.colorWallpaper), "#"))
		lines = append(lines, ui.MutedText.Render(fmt.Sprintf("Solid color (%s)", bgHex)))
	} else {
		lines = append(lines, ui.SectionTitle("Active Wallpaper"))
		currentWp := m.value("wallpaper.current", "")
		wpName := "No wallpaper set"
		if currentWp != "" {
			wpName = filepath.Base(currentWp)
		}
		if mode == "folder" {
			interval := intervalLabel(m.value("wallpaper.interval", "3600"))
			wpName = fmt.Sprintf("%s (rotating every %s)", wpName, interval)
		}
		lines = append(lines, ui.MutedText.Render(ui.TruncatePlain(wpName, max(12, width-2))))
	}

	return strings.Join(lines, "\n")
}

func (m Model) wallpaperPreview(width, height int) string {
	width = max(22, width)
	height = max(6, height)
	innerW := max(14, width-4)
	innerH := max(4, height-2)
	pal := m.palette()

	var imageView string
	if m.value("wallpaper.mode", "file") == "color" {
		line := strings.Repeat(" ", innerW)
		var block []string
		for i := 0; i < innerH; i++ {
			block = append(block, lipgloss.NewStyle().Background(pal.colorWallpaper).Render(line))
		}
		imageView = strings.Join(block, "\n")
	} else {
		imageView = renderImagePreview(expandPath(m.value("wallpaper.current", "")), innerW, innerH)
		if imageView == "" {
			imageView = m.previewPlaceholder("Wallpaper", ui.ShortPath(m.value("wallpaper.current", "-")), innerW, innerH)
		}
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
		return ui.SectionTitle("Themes") + "\n" + ui.MutedText.Render("No themes available")
	}
	pal := m.palette()
	lines := []string{
		ui.SectionTitle("Themes"),
		ui.MutedText.Render(ui.TruncateStyled("Choose a theme. Enter applies the selected theme.", width)),
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
		style = style.Border(lipgloss.ThickBorder()).BorderForeground(m.palette().accent)
	} else {
		style = style.Border(lipgloss.HiddenBorder())
	}
	return style.Render(tile)
}



func (m Model) intervalSelect() string {
	return ui.CycleLine("Interval", intervalLabel(m.value("wallpaper.interval", "3600")), "[/]", false)
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
	current := atoi(m.value("wallpaper.interval", "3600"), 3600)
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
		background:     bgC,
		panel:          blend(bgC, fgC, 0.08),
		panelSoft:      blend(bgC, fgC, 0.14),
		line:           blend(bgC, fgC, 0.28),
		text:           fgC,
		muted:          blend(bgC, fgC, 0.68),
		accent:         accentC,
		colorWallpaper: blend(bgC, accentC, 0.08),
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
	case action == "wallpaper-pick-path":
		return "Wallpaper path selected"
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
	sec := atoi(s, 3600)
	if sec >= 3600 {
		return fmt.Sprintf("%dh", sec/3600)
	}
	if sec >= 60 {
		return fmt.Sprintf("%dm", sec/60)
	}
	return fmt.Sprintf("%ds", sec)
}

func (m Model) handleKey(key string) (tea.Model, tea.Cmd) {
	switch key {
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

	case "c":
		if !m.busy && m.value("wallpaper.mode", "file") != "color" {
			m.busy = true
			return m, m.runAction("wallpaper-set-color")
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
	return m, nil
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
