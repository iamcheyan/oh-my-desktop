-- Extra autostart processes.
-- o.launch_on_start("my-service")
local state_home = os.getenv("SUMIKA_SHELL_STATE_HOME") or (os.getenv("XDG_STATE_HOME") or os.getenv("HOME") .. "/.local/state") .. "/sumika-shell"
o.exec_on_start("mkdir -p " .. state_home .. "/toggles && touch " .. state_home .. "/toggles/waybar-off")
o.exec_on_start("pkill -x waybar || true")
o.exec_on_start((os.getenv("OMD_ROOT") or "") .. "/bin/omd-restart")
o.exec_on_start((os.getenv("OMD_ROOT") or "") .. "/bin/omd-wallpaper restore")
