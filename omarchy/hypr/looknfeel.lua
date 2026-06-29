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

-- Float and center our new Wi-Fi TUI manager with premium sizing
o.window("org.omarchy.omarchy-wifi-tui", { tag = "+floating-window", size = { 1000, 700 } })
o.window("org.omd.impala", { tag = "+floating-window", size = { 1000, 700 } })
o.window("org.omd.wifitui", { tag = "+floating-window", size = { 1000, 700 } })
o.window("org.omd.bluetui", { tag = "+floating-window", size = { 1000, 700 } })
o.window("org.omarchy.voice-test-tui", { tag = "+floating-window", size = { 1000, 700 } })
o.window("org.omarchy.voice-bind-tui", { tag = "+floating-window", size = { 1000, 700 } })
o.window("org.omarchy.key-test", { tag = "+floating-window", size = { 1000, 700 } })
o.window("org.omarchy.voice-diagnose", { tag = "+floating-window", size = { 1000, 700 } })

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
