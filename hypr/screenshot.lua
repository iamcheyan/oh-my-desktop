-- Screenshot & capture keybindings — the single place to change every
-- screenshot shortcut. The bar's screenshot menu ("Screenshot Settings")
-- opens this file in an editor and reloads Hyprland when the editor exits;
-- manual edits just need `hyprctl reload` (SUPER + R).
--
-- Key syntax is standard Hyprland: "ALT + S", "PRINT", "SUPER + CTRL + S", …
-- The actions below are provided by the screenshot extension
-- (sumika-screenshot / sumika-action); keep the paths.root prefix.
local paths = require("default.hypr.paths")

-- Region selector lives in the on-demand sumika-screenshot process.
-- Re-press while open cancels (handled inside sumika-screenshot).
o.bind("ALT + S", "Region screenshot", paths.root .. "/bin/sumika-action screenshot.capture")
o.bind("ALT + SHIFT + S", "Region screenshot (edit)", paths.root .. "/bin/sumika-action screenshot.capture-edit")

o.bind("PRINT", "Screenshot", paths.root .. "/bin/sumika-action screenshot.capture")
o.bind("SUPER + CTRL + PRINT", "Extract text (OCR) from screenshot", paths.root .. "/bin/sumika-action screenshot.capture-ocr")
o.bind("SUPER + PRINT", "Color picker", paths.root .. "/bin/sumika-action display.color-picker")
