-- Volume, brightness, keyboard backlight, and touchpad controls.
o.bind("XF86AudioRaiseVolume", "Volume up", "omd-swayosd-client --output-volume raise", { locked = true, repeating = true })
o.bind("XF86AudioLowerVolume", "Volume down", "omd-swayosd-client --output-volume lower", { locked = true, repeating = true })
o.bind("XF86AudioMute", "Mute", "omd-swayosd-client --output-volume mute-toggle", { locked = true, repeating = true })
o.bind("XF86AudioMicMute", "Mute microphone", "omd-audio-input-mute", { locked = true, repeating = true })
o.bind("XF86MonBrightnessUp", "Brightness up", "omd-brightness-display +5%", { locked = true, repeating = true })
o.bind("XF86MonBrightnessDown", "Brightness down", "omd-brightness-display 5%-", { locked = true, repeating = true })
o.bind("SHIFT + XF86MonBrightnessUp", "Brightness maximum", "omd-brightness-display 100%", { locked = true, repeating = true })
o.bind("SHIFT + XF86MonBrightnessDown", "Brightness minimum", "omd-brightness-display 1%", { locked = true, repeating = true })
o.bind("XF86KbdBrightnessUp", "Keyboard brightness up", "omd-brightness-keyboard up", { locked = true, repeating = true })
o.bind("XF86KbdBrightnessDown", "Keyboard brightness down", "omd-brightness-keyboard down", { locked = true, repeating = true })
o.bind("XF86KbdLightOnOff", "Keyboard backlight cycle", "omd-brightness-keyboard cycle", { locked = true })
o.bind("XF86TouchpadToggle", "Toggle touchpad", "omd-toggle-touchpad", { locked = true })
o.bind("XF86TouchpadOn", "Enable touchpad", "omd-toggle-touchpad on", { locked = true })
o.bind("XF86TouchpadOff", "Disable touchpad", "omd-toggle-touchpad off", { locked = true })

-- Precise volume and brightness controls.
o.bind("ALT + XF86AudioRaiseVolume", "Volume up precise", "omd-swayosd-client --output-volume +1", { locked = true, repeating = true })
o.bind("ALT + XF86AudioLowerVolume", "Volume down precise", "omd-swayosd-client --output-volume -1", { locked = true, repeating = true })
o.bind("ALT + XF86MonBrightnessUp", "Brightness up precise", "omd-brightness-display +1%", { locked = true, repeating = true })
o.bind("ALT + XF86MonBrightnessDown", "Brightness down precise", "omd-brightness-display 1%-", { locked = true, repeating = true })

-- Media controls.
o.bind("XF86AudioNext", "Next track", "omd-swayosd-client --playerctl next", { locked = true })
o.bind("XF86AudioPause", "Pause", "omd-swayosd-client --playerctl play-pause", { locked = true })
o.bind("XF86AudioPlay", "Play", "omd-swayosd-client --playerctl play-pause", { locked = true })
o.bind("XF86AudioPrev", "Previous track", "omd-swayosd-client --playerctl previous", { locked = true })

o.bind("SUPER + XF86AudioMute", "Switch audio output", "omd-audio-output-switch", { locked = true })
