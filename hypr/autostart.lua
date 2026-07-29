-- Extra autostart processes.
-- o.launch_on_start("my-service")
local state_home = os.getenv("SUMIKA_SHELL_STATE_HOME") or (os.getenv("XDG_STATE_HOME") or os.getenv("HOME") .. "/.local/state") .. "/sumika-shell"
local data_home = os.getenv("XDG_DATA_HOME") or os.getenv("HOME") .. "/.local/share"
local ext_dir = (os.getenv("SUMIKA_SHELL_EXTENSIONS_DIR") or data_home .. "/sumika-shell/extensions") .. "/theme-settings"
local shell_root = require("default.hypr.paths").root
o.exec_on_start(shell_root .. "/bin/sumika-restart")
local wallpaper = ext_dir .. "/bin/sumika-wallpaper"
local wallpaper_file = io.open(wallpaper, "r")
if wallpaper_file then
  wallpaper_file:close()
  o.exec_on_start(wallpaper .. " restore")
end
