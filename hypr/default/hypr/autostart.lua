o.launch_on_start("hypridle -c " .. (os.getenv("OMD_ROOT") or "") .. "/hypr/hypridle.conf")
-- Notifications are handled by the OMD bar notification server.
o.launch_on_start("fcitx5 --disable notificationitem")
-- Wallpaper rendering is owned by hypr/autostart.lua through omd-wallpaper.
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
o.exec_on_start("omd-powerprofiles-init")
o.launch_on_start("omd-hyprland-monitor-watch")

-- Slow app launch fix -- set systemd vars.
o.exec_on_start("systemctl --user import-environment $(env | cut -d'=' -f 1)")
o.exec_on_start("dbus-update-activation-environment --systemd --all")
