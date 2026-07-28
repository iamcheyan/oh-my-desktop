local paths = require("default.hypr.paths")

-- Volume, brightness, keyboard backlight, and touchpad controls — routed through ActionManager.
o.bind("XF86AudioRaiseVolume", "Volume up", paths.root .. "/bin/sumika-action audio.volume-up", { locked = true, repeating = true })
o.bind("XF86AudioLowerVolume", "Volume down", paths.root .. "/bin/sumika-action audio.volume-down", { locked = true, repeating = true })
o.bind("XF86AudioMute", "Mute", paths.root .. "/bin/sumika-action audio.volume-mute-toggle", { locked = true, repeating = true })
o.bind("XF86AudioMicMute", "Mute microphone", paths.root .. "/bin/sumika-action audio.input-mute-toggle", { locked = true, repeating = true })
o.bind("XF86MonBrightnessUp", "Brightness up", paths.root .. "/bin/sumika-action display.brightness-up", { locked = true, repeating = true })
o.bind("XF86MonBrightnessDown", "Brightness down", paths.root .. "/bin/sumika-action display.brightness-down", { locked = true, repeating = true })
o.bind("SHIFT + XF86MonBrightnessUp", "Brightness maximum", paths.root .. "/bin/sumika-action display.brightness-max", { locked = true, repeating = true })
o.bind("SHIFT + XF86MonBrightnessDown", "Brightness minimum", paths.root .. "/bin/sumika-action display.brightness-min", { locked = true, repeating = true })
o.bind("XF86KbdBrightnessUp", "Keyboard brightness up", paths.root .. "/bin/sumika-action display.kbd-brightness-up", { locked = true, repeating = true })
o.bind("XF86KbdBrightnessDown", "Keyboard brightness down", paths.root .. "/bin/sumika-action display.kbd-brightness-down", { locked = true, repeating = true })
o.bind("XF86KbdLightOnOff", "Keyboard backlight cycle", paths.root .. "/bin/sumika-action display.kbd-brightness-cycle", { locked = true })
o.bind("XF86TouchpadToggle", "Toggle touchpad", paths.root .. "/bin/sumika-action input.touchpad-toggle", { locked = true })
o.bind("XF86TouchpadOn", "Enable touchpad", paths.root .. "/bin/sumika-action input.touchpad-enable", { locked = true })
o.bind("XF86TouchpadOff", "Disable touchpad", paths.root .. "/bin/sumika-action input.touchpad-disable", { locked = true })

-- Precise volume and brightness controls.
o.bind("ALT + XF86AudioRaiseVolume", "Volume up precise", paths.root .. "/bin/sumika-action audio.volume-up-precise", { locked = true, repeating = true })
o.bind("ALT + XF86AudioLowerVolume", "Volume down precise", paths.root .. "/bin/sumika-action audio.volume-down-precise", { locked = true, repeating = true })
o.bind("ALT + XF86MonBrightnessUp", "Brightness up precise", paths.root .. "/bin/sumika-action display.brightness-up-precise", { locked = true, repeating = true })
o.bind("ALT + XF86MonBrightnessDown", "Brightness down precise", paths.root .. "/bin/sumika-action display.brightness-down-precise", { locked = true, repeating = true })

-- Media controls.
o.bind("XF86AudioNext", "Next track", paths.root .. "/bin/sumika-action mpris.next", { locked = true })
o.bind("XF86AudioPause", "Pause", paths.root .. "/bin/sumika-action mpris.play-pause", { locked = true })
o.bind("XF86AudioPlay", "Play", paths.root .. "/bin/sumika-action mpris.play-pause", { locked = true })
o.bind("XF86AudioPrev", "Previous track", paths.root .. "/bin/sumika-action mpris.previous", { locked = true })

o.bind("SUPER + XF86AudioMute", "Switch audio output", paths.root .. "/bin/sumika-action audio.output-switch", { locked = true })
