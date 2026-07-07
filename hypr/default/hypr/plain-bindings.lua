require("default.hypr.bindings.media")
require("default.hypr.bindings.clipboard")
require("default.hypr.bindings.tiling-v2")
require("default.hypr.bindings.utilities")

-- Application bindings without Omarchy's preinstalled web apps, TUIs, or desktop apps.
o.bind("SUPER + RETURN", "Terminal", { omd = "terminal" })
o.bind("SUPER + SHIFT + RETURN", "Browser", { omd = "browser" })
o.bind("SUPER + SHIFT + F", "File manager", { omd = "nautilus" })
o.bind("SUPER + ALT + SHIFT + F", "File manager (cwd)", { omd = "nautilus-cwd" })
o.bind("SUPER + SHIFT + B", "Browser", { omd = "browser" })
o.bind("SUPER + SHIFT + ALT + B", "Browser (private)", { omd = "browser --private" })
o.bind("SUPER + SHIFT + N", "Editor", { omd = "editor" })
