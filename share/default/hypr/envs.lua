local paths = require("default.hypr.paths")

local function require_file_if_exists(path, module)
  local file = io.open(path, "r")
  if file then
    file:close()
    require(module)
  end
end

-- GUM environment variables for styling purposes.
require_file_if_exists(paths.config_home .. "/omarchy/current/theme/gum_env.lua", "omarchy.current.theme.gum_env")

-- Cursor size.
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Force all apps to use Wayland.
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")

-- Check if KDE Plasma theme integration is available.
local has_kde = false
local kdethemes = {
  "/usr/lib64/qt6/plugins/platformthemes/KDEPlasmaPlatformTheme6.so",
  "/usr/lib/qt6/plugins/platformthemes/KDEPlasmaPlatformTheme6.so",
  "/usr/lib64/qt5/plugins/platformthemes/libqkde.so",
  "/usr/lib/qt5/plugins/platformthemes/libqkde.so",
}
for _, path in ipairs(kdethemes) do
  local f = io.open(path, "r")
  if f then
    f:close()
    has_kde = true
    break
  end
end

if has_kde then
  hl.env("QT_QPA_PLATFORMTHEME", "kde")
else
  hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
end

hl.env("QT_STYLE_OVERRIDE", "kvantum")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("OZONE_PLATFORM", "wayland")
hl.env("XDG_SESSION_TYPE", "wayland")

-- Allow better support for screen sharing (Google Meet, Discord, etc).
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Use XCompose file.
hl.env("XCOMPOSEFILE", paths.home .. "/.XCompose")

hl.config({
  xwayland = {
    force_zero_scaling = true,
  },

  ecosystem = {
    no_update_news = true,
  },
})
