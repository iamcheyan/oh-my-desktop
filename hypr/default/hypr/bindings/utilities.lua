o.bind("SUPER + CTRL + E", "Emoji picker", { omd = "walker -m symbols" })
o.bind("XF86Calculator", "Calculator", "gnome-calculator")

o.bind("SUPER + BACKSPACE", "Toggle window transparency", "omd-hyprland-window-transparency-toggle")
o.bind("SUPER + SHIFT + BACKSPACE", "Toggle window gaps", "omd-hyprland-window-gaps-toggle")
o.bind("SUPER + CTRL + BACKSPACE", "Toggle single-window square aspect", "omd-hyprland-window-single-square-aspect-toggle")

o.bind("SUPER + COMMA", "Dismiss last notification", "makoctl dismiss")
o.bind("SUPER + SHIFT + COMMA", "Dismiss all notifications", "makoctl dismiss --all")
o.bind("SUPER + CTRL + COMMA", "Toggle silencing notifications", "omd-toggle-notification-silencing")
o.bind("SUPER + ALT + COMMA", "Invoke last notification", "makoctl invoke")
o.bind("SUPER + SHIFT + ALT + COMMA", "Restore last notification", "makoctl restore")

o.bind_toggle("SUPER + CTRL + I", "Toggle locking on idle", "idle")
o.bind_toggle("SUPER + CTRL + N", "Toggle nightlight", "nightlight")
o.bind("SUPER + CTRL + Delete", "Toggle laptop display", "omd-hyprland-monitor-internal toggle")
o.bind("SUPER + CTRL + ALT + Delete", "Toggle laptop display mirroring", "omd-hyprland-monitor-internal-mirror toggle")
o.bind("switch:on:Lid Switch", nil, "omd-hw-external-monitors && omd-hyprland-monitor-internal off", { locked = true })
o.bind("switch:off:Lid Switch", nil, "omd-hyprland-monitor-internal on", { locked = true })

o.bind("PRINT", "Screenshot", "omd-capture-screenshot")
o.bind("SUPER + PRINT", "Color picker", "pkill hyprpicker || hyprpicker -a")
o.bind("SUPER + CTRL + PRINT", "Extract text (OCR) from screenshot", "omd-capture-text-extraction")

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

o.bind("SUPER + CTRL + L", "Lock system", "omd-lock")
