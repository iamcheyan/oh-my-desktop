-- Extra autostart processes.
-- o.launch_on_start("my-service")
local state_home = os.getenv("SUMIKA_SHELL_STATE_HOME") or (os.getenv("XDG_STATE_HOME") or os.getenv("HOME") .. "/.local/state") .. "/sumika-shell"
local data_home = os.getenv("XDG_DATA_HOME") or os.getenv("HOME") .. "/.local/share"
local ext_dir = (os.getenv("SUMIKA_SHELL_EXTENSIONS_DIR") or data_home .. "/sumika-shell/extensions") .. "/theme-settings"
o.exec_on_start((os.getenv("OMD_ROOT") or "") .. "/bin/omd-restart")
o.exec_on_start(ext_dir .. "/bin/omd-wallpaper restore")
