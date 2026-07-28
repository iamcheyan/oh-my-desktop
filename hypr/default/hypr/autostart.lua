local shell_root = require("default.hypr.paths").root
o.launch_on_start("hypridle -c " .. shell_root .. "/hypr/hypridle.conf")
-- Notifications are handled by the Sumika bar notification server.
-- Wallpaper rendering is owned by hypr/autostart.lua through sumika-wallpaper.
-- Starting swaybg here as well races folder rotation and monitor hotplug repair.
local function file_exists(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

local polkit_agent = "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
if file_exists(polkit_agent) then
  o.exec_on_start(polkit_agent)
end
o.exec_on_start("sumika-powerprofiles-init")
o.launch_on_start("sumika-hyprland-monitor-watch")

-- Slow app launch fix -- set systemd vars.
o.exec_on_start("systemctl --user import-environment $(env | cut -d'=' -f 1)")
o.exec_on_start("dbus-update-activation-environment --systemd --all")
