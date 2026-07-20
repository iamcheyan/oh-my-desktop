-- Control your input devices.
-- https://wiki.hypr.land/Configuring/Basics/Variables/#input
-- Personal overrides live in ~/.config/sumika-shell/hypr/input.lua
hl.config({
  input = {
    kb_layout = "us",
    kb_options = "compose:caps",
    touchpad = {
      tap_to_click = true,
    },
  },
})
