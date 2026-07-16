-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Load OMD Hyprland modules from the repo linked at ~/.config/omd.
local omd_root = os.getenv("OMD_ROOT") or (os.getenv("HOME") .. "/.config/omd")
package.path = omd_root
  .. "/hypr/?.lua;"
  .. omd_root
  .. "/?.lua;"
  .. package.path

-- OMD's current base layer is copied from the old Omarchy Hyprland defaults
-- and is trimmed/migrated in this repo instead of loaded from ~/.local/share.
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

-- Toggle config flags dynamically.
require("default.hypr.toggles")

do
  local rules = io.open(omd_root .. "/hypr/window_rules.lua", "r")
  if rules then
    rules:close()
    require("window_rules")
  end
end
