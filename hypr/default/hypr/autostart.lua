o.launch_on_start("hypridle")
o.launch_on_start("mako")
o.launch_on_start("fcitx5 --disable notificationitem")
o.launch_on_start("swaybg -i ~/.config/omd/current/background -m fill")
o.exec_on_start("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
o.exec_on_start("omd-powerprofiles-init")
o.launch_on_start("omd-hyprland-monitor-watch")

-- Slow app launch fix -- set systemd vars.
o.exec_on_start("systemctl --user import-environment $(env | cut -d'=' -f 1)")
o.exec_on_start("dbus-update-activation-environment --systemd --all")
