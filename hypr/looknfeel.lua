-- Change the default Omarchy look'n'feel.

-- Disable opacity on inactive windows (keep all windows fully opaque).
hl.config({
  decoration = {
    active_opacity = 1.0,
    inactive_opacity = 1.0,
  },
})

-- Override default-opacity window rule (Omarchy sets 0.97/0.9 for all windows).
o.window(".*", { tag = "-default-opacity", opacity = "1.0 1.0" })

-- Configure window spacing (gaps_in=2, gaps_out=4)
hl.config({
  general = {
    gaps_in = 2,
    gaps_out = 4,
  },
})

-- Blur translucent Quickshell layer surfaces so TuiStyle glass tokens render
-- as frosted glass instead of plain alpha over the wallpaper.
hl.layer_rule({ match = { namespace = "quickshell:.*" }, blur = true, ignore_alpha = 0.1 })

-- 关闭应用启动器和剪贴板的图层过渡动画，使其在冷启动下直接瞬间弹出，以达到极致的高性能响应
hl.layer_rule({ match = { namespace = "quickshell:appLauncher" }, no_anim = true })
hl.layer_rule({ match = { namespace = "quickshell:clipboard" }, no_anim = true })

-- Float and center transient TUI / GUI settings managers
o.window("org.omarchy.omarchy-wifi-tui", { float = true, center = true, size = { 1000, 700 } })
o.window("org.omd.impala", { float = true, center = true, size = { 1000, 700 } })
o.window("org.omd.wifitui", { float = true, center = true, size = { 1000, 700 } })
o.window("org.omd.bluetui", { float = true, center = true, size = { 1000, 700 } })
o.window("org.omd.voice-test-tui", { float = true, center = true, size = { 1000, 700 } })
o.window("org.omd.voice-bind-tui", { float = true, center = true, size = { 1000, 700 } })
o.window("org.omarchy.key-test", { float = true, center = true, size = { 1000, 700 } })
o.window("org.omd.voice-diagnose", { float = true, center = true, size = { 1000, 700 } })

-- Flatpak install progress terminal (scripts/flatpak-launch) floats and centers
o.window("org.omd.flatpak-install", { float = true, center = true, size = { 880, 620 } })

-- nmtui runs inside foot; float, center, and size it to fit the TUI content
o.window("^nmtui$", { float = true, center = true, size = { 880, 620 } })

-- GUI settings managers float and center. GTK4 pavucontrol's persisted
-- 530px-wide default is too narrow for its translated tab and device labels,
-- while GTK3 Blueman is best left at its own content-aware size.
o.window("nm-connection-editor", { float = true, center = true })
o.window("blueman-manager", { float = true, center = true })
o.window("org.pulseaudio.pavucontrol", { float = true, center = true, size = { 900, 700 } })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
-- hl.config({
--   decoration = {
--     -- Use round window corners.
--     rounding = 8,
--
--     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
--     dim_inactive = true,
--     dim_strength = 0.15,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })

-- Force standard cursor theme (Adwaita) and bypass Hyprland's bibata waterdrop fallback
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("HYPRCURSOR_THEME", "Adwaita")
o.exec_on_start("hyprctl setcursor Adwaita 24")
