local paths = require("default.hypr.paths")

-- Application bindings.
o.bind("SUPER + RETURN", "Application launcher", paths.root .. "/bin/sumika-action app-launcher.toggle")
o.bind("SUPER + A", "Toggle application launcher", paths.root .. "/bin/sumika-action app-launcher.toggle")
o.bind("SUPER + Q", "Terminal", { sumika = "terminal" })
o.bind("SUPER + ALT + RETURN", "Tmux", { sumika = "terminal-tmux" })
o.bind("SUPER + SHIFT + RETURN", "Browser", { sumika = "browser" })
o.bind("SUPER + SHIFT + B", "Browser", { sumika = "browser" })
o.bind("SUPER + SHIFT + ALT + B", "Browser (private)", { sumika = "browser --private" })
o.bind("SUPER + SHIFT + N", "Editor", { sumika = "editor" })

-- App-specific bindings (uncomment and adjust to your installed apps).
-- o.bind("SUPER + SHIFT + F", "File manager", { sumika = "nautilus" })
-- o.bind("SUPER + ALT + SHIFT + F", "File manager (cwd)", { sumika = "nautilus-cwd" })
-- o.bind("SUPER + SHIFT + M", "Music", { sumika = "or-focus spotify" })
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

o.bind("SUPER + CTRL + B", "Bluetooth", paths.root .. "/bin/sumika-action bluetooth.launch")

o.bind("SUPER + CTRL + W", "WiFi", paths.root .. "/bin/sumika-action wifi.launch")

-- Change window move/resize modifier from SUPER to ALT.
hl.unbind("SUPER + mouse:272")
hl.unbind("SUPER + mouse:273")
o.bind("ALT + mouse:272", "Move window", hl.dsp.window.drag(), { mouse = true })
o.bind("ALT + mouse:273", "Resize window", hl.dsp.window.resize(), { mouse = true })

-- Input method schema cycling via ActionManager.
o.bind("SUPER + SPACE", "Next input language", paths.root .. "/bin/sumika-action input-method.cycle")
o.bind("SUPER + SHIFT + SPACE", "Previous input language", paths.root .. "/bin/sumika-action input-method.cycle -- -1")
hl.unbind("SUPER + CTRL + SPACE")
o.bind("SUPER + CTRL + SPACE", "Toggle Quickshell bar", paths.root .. "/bin/sumika-action bar.toggle")

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

-- Overview exposes a global dynamic list of occupied workspaces plus one
-- trailing empty slot per monitor. Real Hyprland workspace IDs may contain
-- gaps, so SUPER+number targets the global visible slot instead of assuming
-- Slot N has raw ID N.
for slot = 1, 10 do
  local key = "code:" .. tostring(slot + 9)
  hl.unbind("SUPER + " .. key)
  hl.bind("SUPER + " .. key, hl.dsp.global("quickshell:workspaceSlot" .. tostring(slot)), {
    description = "Switch to workspace slot " .. tostring(slot)
  })
end

-- SUPER+D: jump to the last blank workspace (or create a fresh one after the
-- highest). Pressing again while that scratch workspace is still empty returns
-- to the workspace you came from; if it now has content, another blank
-- workspace is opened instead. State lives in $SUMIKA_SHELL_STATE_HOME.
o.bind("SUPER + D", "Toggle blank workspace", paths.root .. "/bin/sumika-hyprland-workspace-scratch-toggle")

-- Esc closes active bar menus/popups (transparent so apps still get it when no menu is open)
hl.bind("ESCAPE", hl.dsp.exec_cmd(paths.root .. '/bin/sumika-action menus.close 2>/dev/null'), {
  ignore_mods = true, transparent = true, non_consuming = true, description = "Close active bar menus"
})

-- Context-menu mnemonic keys: each bare letter routes to the bar's
-- menus.mnemonic action, which activates the hovered context-menu item whose
-- mnemonic matches. `transparent` + `non_consuming` means the key still reaches
-- any focused text input (terminal, editor) — the bind only fires when no app
-- claims the key, so typing elsewhere is never hijacked. The action itself is a
-- no-op unless a ContextMenuWindow is open and the pointer is over it.
for _, letter in ipairs({
  "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
  "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"
}) do
  hl.bind(letter, hl.dsp.exec_cmd(paths.root .. '/bin/sumika-action menus.mnemonic ' .. letter .. ' 2>/dev/null'), {
    transparent = true, non_consuming = true,
    description = "Context-menu mnemonic " .. letter
  })
end

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

local function read_sasayaki_bindings()
  local data_home = os.getenv("XDG_DATA_HOME") or (paths.home .. "/.local/share")
  local extensions_dir = os.getenv("SUMIKA_SHELL_EXTENSIONS_DIR") or (data_home .. "/sumika-shell/extensions")
  -- Use absolute paths: the Hyprland process PATH does not include
  -- extensions/bin, so bare command names silently fail and the bindings
  -- fall back to ALT+A. Note the sasayaki subcommand is `bindings`,
  -- NOT `hypr-bindings` (the latter is the voice helper's name).
  local candidates = {
    { extensions_dir .. "/sasayaki/sasayaki", "bindings" },
    { extensions_dir .. "/voice/bin/sumika-voice-translate", "hypr-bindings" },
    { "sasayaki", "bindings" },
  }
  local result = { voice = {}, voicetap = {}, translation = nil }
  for _, c in ipairs(candidates) do
    local process = io.popen("'" .. c[1]:gsub("'", "'\\''") .. "' " .. c[2] .. " 2>/dev/null")
    if process then
      local any = false
      for line in process:lines() do
        local kind, binding = line:match("^([^\t]+)\t(.+)$")
        if kind == "voice" and binding and binding ~= "" then
          table.insert(result.voice, binding)
          any = true
        elseif kind == "translation" and binding and binding ~= "" then
          result.translation = binding
          any = true
        elseif kind == "voicetap" and binding and binding ~= "" then
          table.insert(result.voicetap, binding)
          any = true
        end
      end
      process:close()
      if any and #result.voice > 0 then
        break
      end
    end
  end
  return result
end

local voice_config = read_sasayaki_bindings()
if #voice_config.voice == 0 then
  voice_config.voice = { "ALT + A" }
end

for _, key in ipairs(voice_config.voice) do
    o.bind(key, "Voice input toggle", paths.root .. "/bin/sumika-action sasayaki.toggle")
end

-- CapsLock wake (`sasayaki capslock on`): tap the CapsLock-position key to
-- toggle voice input in every state — swap on or off, any layout.
--   * code:66 — the caps-lock keycode. Covers the unswapped caps position
--     and the bottom-left key when ctrl-caps-swap moves the capslock ROLE
--     there. Stable across XKB keysym remaps (compose:caps). Kept
--     transparent so caps/compose behavior still reaches clients.
--   * F24 — emitted by keyd overload(leftcontrol, f24) on the caps
--     position when the swap preset is active with wake on: hold = Ctrl
--     (chords untouched), bare tap = F24. Consumed: no app expects it.
-- Both are release-only, so they fire exactly on a completed bare tap.
for _, tap in ipairs(voice_config.voicetap) do
  hl.bind(tap, hl.dsp.exec_cmd(paths.root .. "/bin/sumika-action sasayaki.toggle"), {
    release = true,
    transparent = tap:sub(1, 5) == "code:",
    description = "Voice input (CapsLock tap)" })
end
-- Dedicated translation trigger captured by Sumika KeyTest:
-- bind HANGUL · XKB keycode 130 · evdev 122.
o.bind(voice_config.translation or "HANGUL", "Translated voice input toggle", paths.root .. "/bin/sumika-action sasayaki.translate-toggle")
o.bind("ALT + SHIFT + A", "Repair Sasayaki", paths.root .. "/bin/sumika-action sasayaki.repair")
o.bind("ALT + S", "Region screenshot", paths.root .. "/bin/sumika-action screenshot.capture")
o.bind("ALT + SHIFT + S", "Region screenshot (edit)", paths.root .. "/bin/sumika-action screenshot.capture-edit")

o.bind("ALT + V", "Clipboard manager", paths.root .. "/bin/sumika-action clipboard.toggle")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
hl.unbind("SUPER + CTRL + V")
