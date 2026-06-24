-- Application bindings.
o.bind("SUPER + RETURN", "Terminal", { omarchy = "terminal" })
o.bind("SUPER + ALT + RETURN", "Tmux", { omarchy = "terminal-tmux" })
o.bind("SUPER + SHIFT + RETURN", "Browser", { omarchy = "browser" })
o.bind("SUPER + SHIFT + B", "Browser", { omarchy = "browser" })
o.bind("SUPER + SHIFT + ALT + B", "Browser (private)", { omarchy = "browser --private" })
o.bind("SUPER + SHIFT + N", "Editor", { omarchy = "editor" })

-- App-specific bindings (uncomment and adjust to your installed apps).
-- o.bind("SUPER + SHIFT + F", "File manager", { omarchy = "nautilus" })
-- o.bind("SUPER + ALT + SHIFT + F", "File manager (cwd)", { omarchy = "nautilus-cwd" })
-- o.bind("SUPER + SHIFT + M", "Music", { omarchy = "or-focus spotify" })
-- o.bind("SUPER + SHIFT + ALT + M", "Music TUI", { tui = "cliamp", focus = true })
-- o.bind("SUPER + SHIFT + D", "Docker", { tui = "lazydocker" })
-- o.bind("SUPER + SHIFT + G", "Signal", { launch = "signal-desktop", focus = "^signal$" })
-- o.bind("SUPER + SHIFT + O", "Obsidian", { launch = "obsidian", focus = "^obsidian$" })
-- o.bind("SUPER + SHIFT + W", "Typora", { launch = "typora --enable-wayland-ime" })
-- o.bind("SUPER + SHIFT + SLASH", "Passwords", { launch = "1password" })

-- Web app bindings (uncomment and adjust to your preferences).
-- o.bind("SUPER + SHIFT + A", "ChatGPT", { webapp = "https://chatgpt.com" })
-- o.bind("SUPER + SHIFT + C", "Calendar", { webapp = "https://calendar.google.com" })
-- o.bind("SUPER + SHIFT + E", "Email", { webapp = "https://mail.google.com" })
-- o.bind("SUPER + SHIFT + Y", "YouTube", { webapp = "https://youtube.com/" })
-- o.bind("SUPER + SHIFT + X", "X", { webapp = "https://x.com/" })

-- Add extra bindings below.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change window move/resize modifier from SUPER to ALT.
hl.unbind("SUPER + mouse:272")
hl.unbind("SUPER + mouse:273")
o.bind("ALT + mouse:272", "Move window", hl.dsp.window.drag(), { mouse = true })
o.bind("ALT + mouse:273", "Resize window", hl.dsp.window.resize(), { mouse = true })

-- Overwrite existing bindings with hl.unbind() first if needed.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu")
hl.unbind("SUPER + SHIFT + SPACE")
o.bind("SUPER + SHIFT + SPACE", "Toggle Quickshell bar", "qs -p $HOME/.config/omd/apps/omd-bar ipc call bar toggle")

hl.unbind("SUPER + TAB")
hl.unbind("SUPER + SHIFT + TAB")
hl.bind("SUPER + TAB", hl.dsp.global("quickshell:overviewNext"), { description = "Quickshell switcher next" })
hl.bind("SUPER + SHIFT + TAB", hl.dsp.global("quickshell:overviewPrev"), { description = "Quickshell switcher previous" })
hl.bind("SUPER + SUPER_L", hl.dsp.global("quickshell:overviewCommit"), { release = true, description = "Quickshell switcher commit" })
hl.bind("SUPER + SUPER_R", hl.dsp.global("quickshell:overviewCommit"), { release = true, description = "Quickshell switcher commit" })

-- Track Super key state directly via Quickshell GlobalShortcut so the overview
-- process can detect Super release without IPC relay latency.
hl.bind("SUPER_L", hl.dsp.global("quickshell:workspaceNumber"), { ignore_mods = true, transparent = true })
hl.bind("SUPER_R", hl.dsp.global("quickshell:workspaceNumber"), { ignore_mods = true, transparent = true })
hl.bind("SUPER_L", hl.dsp.global("quickshell:workspaceNumber"), { ignore_mods = true, transparent = true, release = true })
hl.bind("SUPER_R", hl.dsp.global("quickshell:workspaceNumber"), { ignore_mods = true, transparent = true, release = true })

-- Interrupt Super-alone overview toggle: any SUPER+key press clears the
-- "might trigger" flag via a non-consuming transparent bind.
-- We use a catch-all approach: bind common keys with non_consuming so they
-- fire alongside the real bind without intercepting it.
local interrupt_keys = {
  "RETURN", "TAB", "SPACE", "BACKSPACE", "ESCAPE",
  "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
  "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
  "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
  "LEFT", "RIGHT", "UP", "DOWN",
  "GRAVE", "MINUS", "EQUAL",
  "SEMICOLON", "APOSTROPHE", "COMMA", "PERIOD", "SLASH",
  "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
}
for _, key in ipairs(interrupt_keys) do
  hl.bind("SUPER + " .. key, hl.dsp.global("quickshell:superInterrupt"), {
    non_consuming = true, transparent = true, description = "Interrupt Super-alone"
  })
end

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, { omarchy = "walker -m symbols" })
