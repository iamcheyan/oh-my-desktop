local paths = require("default.hypr.paths")
local require_all = require("default.hypr.require_all")

local toggles_dir = paths.xdg_state_home .. "/omd/toggles/hypr"
package.path = toggles_dir .. "/?.lua;" .. package.path

require_all.files(toggles_dir, nil, { reload = true })
