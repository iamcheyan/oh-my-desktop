local shell_root = require("default.hypr.paths").root
o.launch_on_start("hypridle -c " .. shell_root .. "/hypr/hypridle.conf")
-- Notifications are handled by the Sumika bar notification server.
-- Wallpaper rendering is owned by hypr/autostart.lua through sumika-wallpaper.
-- Starting swaybg here as well races folder rotation and monitor hotplug repair.
-- The Quickshell polkit process is started by sumika-restart. Do not start a
-- second desktop agent here.
o.launch_on_start("sumika-hyprland-monitor-watch")

-- Slow app launch fix -- set systemd vars.
o.exec_on_start("systemctl --user import-environment $(env | cut -d'=' -f 1)")
o.exec_on_start("dbus-update-activation-environment --systemd --all")
