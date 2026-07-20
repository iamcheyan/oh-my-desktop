-- OMD Hyprland setup: helpers, defaults, and current theme overrides.

require("default.hypr.helpers")

-- Use Omarchy defaults, but don't edit these directly.
require("default.hypr.autostart")
require("default.hypr.bindings.media")
require("default.hypr.bindings.clipboard")
require("default.hypr.bindings.tiling-v2")
require("default.hypr.bindings.utilities")
require("default.hypr.envs")
require("default.hypr.looknfeel")
require("default.hypr.input")
require("default.hypr.windows")

-- Current theme overrides.
do
  local paths = require("default.hypr.paths")
  local theme_path = paths.state_home .. "/theme/current/hyprland.lua"
  local theme = io.open(theme_path, "r")
  if theme then
    theme:close()
    dofile(theme_path)
  end
end
