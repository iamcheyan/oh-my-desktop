-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Load OMD / Sumika Shell Hyprland modules from the repository.
-- Repository root resolution order:
--   1. SUMIKA_SHELL_ROOT env var (set by updated session wrapper)
--   2. OMD_ROOT env var, with symlinks resolved
--   3. This file's own location (works even if both env vars are stale)
--   4. ~/.config/sumika-shell fallback
local function resolve_root()
  -- Try env vars first
  local env_root = os.getenv("SUMIKA_SHELL_ROOT")
  if not env_root or env_root == "" then
    env_root = os.getenv("OMD_ROOT") or (os.getenv("HOME") .. "/.config/sumika-shell")
  end
  -- Resolve symlinks (works when the symlink still exists)
  if env_root and env_root ~= "" then
    local pipe = io.popen("readlink -f '" .. env_root .. "' 2>/dev/null")
    if pipe then
      local resolved = pipe:read("*l")
      pipe:close()
      if resolved and resolved ~= "" and os.getenv("HOME") and
         io.open(resolved .. "/Init.sh", "r") then
        return resolved
      end
    end
  end
  -- Fallback: derive from this file's location via debug.getinfo
  -- source is like "@/path/to/repo/hypr/hyprland.lua"
  local info = debug.getinfo(1, "S")
  if info and info.source then
    local src = info.source
    -- Strip leading @
    if src:sub(1, 1) == "@" then src = src:sub(2) end
    -- This file is at repo/hypr/hyprland.lua → repo = dirname(dirname(src))
    local hypr_dir = src:match("^(.*)/hypr/")
    if hypr_dir and io.open(hypr_dir .. "/Init.sh", "r") then
      return hypr_dir
    end
  end
  -- Last resort: raw env var even if unresolvable
  return env_root or (os.getenv("HOME") .. "/.config/sumika-shell")
end

local omd_root = resolve_root()

package.path = omd_root
  .. "/hypr/?.lua;"
  .. omd_root
  .. "/?.lua;"
  .. package.path

-- OMD's current base layer is copied from the old Omarchy Hyprland defaults
-- and is trimmed/migrated in this repo instead of being loaded from ~/.local/share.
require("default.hypr.base")

-- Change your own setup in these files and override defaults.
-- Monitor layouts are machine-local state and may change while Hyprland is
-- running. Load this file on every config reload instead of caching it through
-- require().
dofile(omd_root .. "/hypr/monitors.lua")
require("input")
require("bindings")
require("looknfeel")
require("autostart")

-- Load personal overrides from user config (~/.config/sumika-shell/hypr/).
-- These load AFTER the repo's hypr/*.lua, so they can override or add.
local _config_home = os.getenv("SUMIKA_SHELL_CONFIG_HOME")
  or ((os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/sumika-shell")
local _user_hypr = _config_home .. "/hypr"
for _, _name in ipairs({ "input", "bindings", "looknfeel", "autostart" }) do
  local _path = _user_hypr .. "/" .. _name .. ".lua"
  local _f = io.open(_path, "r")
  if _f then
    _f:close()
    dofile(_path)
  end
end

-- Toggle config flags dynamically.
require("default.hypr.toggles")

do
  local rules = io.open(omd_root .. "/hypr/window_rules.lua", "r")
  if rules then
    rules:close()
    require("window_rules")
  end
end