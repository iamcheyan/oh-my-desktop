local paths = require("default.hypr.paths")

o.bind("SUPER + BACKSPACE", "Toggle window transparency", paths.root .. "/bin/sumika-action window.transparency-toggle")
o.bind("SUPER + SHIFT + BACKSPACE", "Toggle window gaps", paths.root .. "/bin/sumika-action window.gaps-toggle")
o.bind("SUPER + CTRL + BACKSPACE", "Toggle single-window square aspect", paths.root .. "/bin/sumika-action window.single-square-aspect-toggle")
o.bind("SUPER + COMMA", "Dismiss last notification", paths.root .. "/bin/sumika-action notifications.dismiss-last")
o.bind("SUPER + SHIFT + COMMA", "Dismiss all notifications", paths.root .. "/bin/sumika-action notifications.dismiss-all")
o.bind("SUPER + CTRL + COMMA", "Toggle silencing notifications", paths.root .. "/bin/sumika-action notifications.toggle-silent")

o.bind("SUPER + CTRL + Delete", "Toggle laptop display", paths.root .. "/bin/sumika-action display.internal-toggle")
o.bind("SUPER + CTRL + ALT + Delete", "Toggle laptop display mirroring", paths.root .. "/bin/sumika-action display.internal-mirror-toggle")
o.bind("switch:on:Lid Switch", nil, paths.root .. "/bin/sumika-action display.lid-close", { locked = true })
o.bind("switch:off:Lid Switch", nil, paths.root .. "/bin/sumika-action display.lid-open", { locked = true })
-- Region selector lives in the on-demand sumika-screenshot process.
-- Re-press while open cancels (handled inside sumika-screenshot).
o.bind("SUPER + PRINT", "Color picker", paths.root .. "/bin/sumika-action display.color-picker")
o.bind("PRINT", "Screenshot", paths.root .. "/bin/sumika-action screenshot.capture")
o.bind("SUPER + CTRL + PRINT", "Extract text (OCR) from screenshot", paths.root .. "/bin/sumika-action screenshot.capture-ocr")

-- Audio/Bluetooth open real registered actions (sumika-launch-profile has
-- no audio/bluetooth/wifi profiles — those bindings were dead). WiFi is
-- already bound in hypr/bindings.lua via wifi.launch; do not double-bind.
o.bind("SUPER + CTRL + A", "Audio controls", paths.root .. "/bin/sumika-action audio.launch")
o.bind("SUPER + CTRL + B", "Bluetooth controls", paths.root .. "/bin/sumika-action bluetooth.launch")
o.bind("SUPER + CTRL + T", "Activity", { tui = "btop" })

o.bind("SUPER + CTRL + Z", "Zoom in", function()
  local zoom = hl.get_config("cursor.zoom_factor") or 1
  hl.config({ cursor = { zoom_factor = zoom + 1 } })
end)

o.bind("SUPER + CTRL + ALT + Z", "Reset zoom", function()
  hl.config({ cursor = { zoom_factor = 1 } })
end)
o.bind("SUPER + CTRL + L", "Lock system", paths.root .. "/bin/sumika-action session.lock")
