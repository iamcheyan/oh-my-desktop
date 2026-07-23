local paths = require("default.hypr.paths")

o.bind("SUPER + BACKSPACE", "Toggle window transparency", "omd-hyprland-window-transparency-toggle")
o.bind("SUPER + SHIFT + BACKSPACE", "Toggle window gaps", "omd-hyprland-window-gaps-toggle")
o.bind("SUPER + CTRL + BACKSPACE", "Toggle single-window square aspect", "omd-hyprland-window-single-square-aspect-toggle")
o.bind("SUPER + COMMA", "Dismiss last notification", paths.omd_root .. "/bin/omd-action notification.dismiss-last")
o.bind("SUPER + SHIFT + COMMA", "Dismiss all notifications", paths.omd_root .. "/bin/omd-action notification.dismiss-all")
o.bind("SUPER + CTRL + COMMA", "Toggle silencing notifications", paths.omd_root .. "/bin/omd-action notification.toggle-silent")

o.bind("SUPER + CTRL + Delete", "Toggle laptop display", "omd-hyprland-monitor-internal toggle")
o.bind("SUPER + CTRL + ALT + Delete", "Toggle laptop display mirroring", "omd-hyprland-monitor-internal-mirror toggle")
o.bind("switch:on:Lid Switch", nil, "omd-hw-external-monitors && omd-hyprland-monitor-internal off", { locked = true })
o.bind("switch:off:Lid Switch", nil, "omd-hyprland-monitor-internal on", { locked = true })
-- Region selector lives in the on-demand omd-screenshot process.
-- Re-press while open cancels (handled inside omd-screenshot).
-- SUPER+PRINT color picker kept as direct exec.
o.bind("SUPER + PRINT", "Color picker", "pkill hyprpicker || hyprpicker -a")
o.bind("PRINT", "Screenshot", paths.omd_root .. "/bin/omd-action screenshot.capture")
o.bind("SUPER + CTRL + PRINT", "Extract text (OCR) from screenshot", paths.omd_root .. "/bin/omd-action screenshot.capture-ocr")

o.bind("SUPER + CTRL + A", "Audio controls", { omd = "audio" })
o.bind("SUPER + CTRL + B", "Bluetooth controls", { omd = "bluetooth" })
o.bind("SUPER + CTRL + W", "Wifi controls", { omd = "wifi" })
o.bind("SUPER + CTRL + T", "Activity", { tui = "btop" })

o.bind("SUPER + CTRL + Z", "Zoom in", function()
  local zoom = hl.get_config("cursor.zoom_factor") or 1
  hl.config({ cursor = { zoom_factor = zoom + 1 } })
end)

o.bind("SUPER + CTRL + ALT + Z", "Reset zoom", function()
  hl.config({ cursor = { zoom_factor = 1 } })
end)
o.bind("SUPER + CTRL + L", "Lock system", paths.omd_root .. "/bin/omd-action session.lock")
