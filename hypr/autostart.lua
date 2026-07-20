-- Extra autostart processes.
-- o.launch_on_start("my-service")
o.exec_on_start("mkdir -p $HOME/.local/state/omd/toggles && touch $HOME/.local/state/omd/toggles/waybar-off")
o.exec_on_start("pkill -x waybar || true")
o.exec_on_start((os.getenv("OMD_ROOT") or "") .. "/bin/omd-restart")
o.exec_on_start((os.getenv("OMD_ROOT") or "") .. "/bin/omd-wallpaper restore")
