local paths = require("default.hypr.paths")

-- Application bindings.
o.bind("SUPER + RETURN", "Application launcher", "$HOME/.config/omd/bin/omd-applauncher")
o.bind("SUPER + Q", "Terminal", { omd = "terminal" })
o.bind("SUPER + ALT + RETURN", "Tmux", { omd = "terminal-tmux" })
o.bind("SUPER + SHIFT + RETURN", "Browser", { omd = "browser" })
o.bind("SUPER + SHIFT + B", "Browser", { omd = "browser" })
o.bind("SUPER + SHIFT + ALT + B", "Browser (private)", { omd = "browser --private" })
o.bind("SUPER + SHIFT + N", "Editor", { omd = "editor" })

-- App-specific bindings (uncomment and adjust to your installed apps).
-- o.bind("SUPER + SHIFT + F", "File manager", { omd = "nautilus" })
-- o.bind("SUPER + ALT + SHIFT + F", "File manager (cwd)", { omd = "nautilus-cwd" })
-- o.bind("SUPER + SHIFT + M", "Music", { omd = "or-focus spotify" })
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

o.bind("SUPER + R", "Reload Hyprland config", "hyprctl reload")

-- Change window move/resize modifier from SUPER to ALT.
hl.unbind("SUPER + mouse:272")
hl.unbind("SUPER + mouse:273")
o.bind("ALT + mouse:272", "Move window", hl.dsp.window.drag(), { mouse = true })
o.bind("ALT + mouse:273", "Resize window", hl.dsp.window.resize(), { mouse = true })

-- Input language switching cycles Rime schemas rather than Fcitx input-method
-- groups. The latter only contains keyboard-us and rime on this setup.
hl.unbind("SUPER + SPACE")
hl.unbind("SUPER + SHIFT + SPACE")
hl.unbind("SUPER + CTRL + SPACE")
o.bind("SUPER + SPACE", "Next input language", "qs -p $HOME/.config/omd/apps/omd-bar ipc call inputMethod cycle 1")
o.bind("SUPER + SHIFT + SPACE", "Previous input language", "qs -p $HOME/.config/omd/apps/omd-bar ipc call inputMethod cycle -1")
o.bind("SUPER + CTRL + SPACE", "Toggle Quickshell bar", "qs -p $HOME/.config/omd/apps/omd-bar ipc call bar toggle")

hl.unbind("SUPER + TAB")
hl.unbind("SUPER + SHIFT + TAB")
hl.bind("SUPER + TAB", hl.dsp.global("quickshell:overviewNext"), { description = "Quickshell overview next" })
hl.bind("SUPER + SHIFT + TAB", hl.dsp.global("quickshell:overviewPrev"), { description = "Quickshell overview previous" })
hl.bind("SUPER + SUPER_L", hl.dsp.global("quickshell:overviewCommit"), { release = true, description = "Quickshell overview commit" })
hl.bind("SUPER + SUPER_R", hl.dsp.global("quickshell:overviewCommit"), { release = true, description = "Quickshell overview commit" })

-- Track Super key state directly via Quickshell GlobalShortcut so the overview
-- process can detect Super release without IPC relay latency.
hl.bind("SUPER_L", hl.dsp.global("quickshell:workspaceNumber"), { ignore_mods = true, transparent = true })
hl.bind("SUPER_R", hl.dsp.global("quickshell:workspaceNumber"), { ignore_mods = true, transparent = true })
hl.bind("SUPER_L", hl.dsp.global("quickshell:workspaceNumber"), { ignore_mods = true, transparent = true, release = true })
hl.bind("SUPER_R", hl.dsp.global("quickshell:workspaceNumber"), { ignore_mods = true, transparent = true, release = true })

-- Esc closes active bar menus/popups (transparent so apps still get it when no menu is open)
hl.bind("ESCAPE", hl.dsp.exec_cmd('qs -p "$HOME/.config/omd/apps/omd-bar" ipc call menus close 2>/dev/null'), {
  ignore_mods = true, transparent = true, non_consuming = true, description = "Close active bar menus"
})

-- Interrupt Super-alone overview toggle: any SUPER+key press clears the
-- "might trigger" flag without consuming the real keybind.
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
    ignore_mods = true, non_consuming = true, transparent = true, description = "Interrupt Super-alone"
  })
end

local function read_voice_bindings(filepath)
  local file = io.open(filepath, "r")
  local list = {}
  if file then
    for line in file:lines() do
      local trimmed = line:gsub("^%s*(.-)%s*$", "%1")
      if trimmed ~= "" and not trimmed:find("^#") then
        table.insert(list, trimmed)
      end
    end
    file:close()
  end
  return list
end

local voice_bindings = read_voice_bindings(paths.omd_root .. "/config/voice_bindings.txt")
if #voice_bindings == 0 then
  voice_bindings = { "ALT + A", "code:472" }
end

for _, key in ipairs(voice_bindings) do
  o.bind(key, "Voice input toggle", "qs -p $HOME/.config/omd/apps/omd-bar ipc call voice toggle")
end
-- Prefer absolute path (same tool as PrintScreen). Re-press cancels if open.
o.bind("ALT + S", "Region screenshot", paths.omd_root .. "/bin/omd-screenshot screenshot")
o.bind("ALT + SHIFT + S", "Region screenshot (edit)", paths.omd_root .. "/bin/omd-screenshot edit")

-- Logitech MX Keys examples:
-- o.bind("SUPER + H", nil, "voxtype record toggle")
hl.unbind("SUPER + CTRL + V")
o.bind("CTRL + SHIFT + V", "Clipboard manager", "$HOME/.config/omd/bin/omd-clipboard")
hl.unbind("SUPER + CTRL + V")
