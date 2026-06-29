-- Extra autostart processes.
-- o.launch_on_start("my-service")
o.exec_on_start("mkdir -p $HOME/.local/state/omarchy/toggles && touch $HOME/.local/state/omarchy/toggles/waybar-off")
o.exec_on_start("pkill -x waybar || true")
o.exec_on_start("$HOME/.config/omd/bin/omd-restart")
o.exec_on_start("$HOME/.config/omd/bin/omd-wallpaper restore")
