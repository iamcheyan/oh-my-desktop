-- Shared path constants for OMD's Hyprland Lua modules.
-- Lua files loaded with require() have separate local scopes, so modules that
-- need these paths import this table instead of repeating os.getenv() lookups.

local home = os.getenv("HOME")
local config_home = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")

return {
  home = home,
  config_home = config_home,
  state_home = os.getenv("XDG_STATE_HOME") or (home .. "/.local/state"),
  omd_root = os.getenv("OMD_ROOT") or (config_home .. "/omd"),
}
