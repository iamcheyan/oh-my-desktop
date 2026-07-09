-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and resolutions possible: hyprctl monitors all

-- Dynamic Monitor Auto-Scaling Configuration for Hyprland
-- Automatically detects connected displays via DRM sysfs and assigns standard scaling.

local function get_connected_monitors()
  local monitors = {}
  -- Probe directory contents using standard Lua io.popen
  local p = io.popen("find /sys/class/drm/ -maxdepth 1 -name \"card*-*\" 2>/dev/null")
  if not p then return monitors end

  for path in p:lines() do
    local status_file = io.open(path .. "/status", "r")
    if status_file then
      local status = status_file:read("*l")
      status_file:close()
      if status == "connected" then
        local name = path:match("card%d+%-([^/]+)")
        local modes_file = io.open(path .. "/modes", "r")
        local mode = "preferred"
        local w, h = 0, 0
        if modes_file then
          local first_line = modes_file:read("*l")
          modes_file:close()
          if first_line then
            mode = first_line
            w, h = first_line:match("(%d+)x(%d+)")
            w, h = tonumber(w or 0), tonumber(h or 0)
          end
        end
        table.insert(monitors, { name = name, mode = mode, w = w, h = h })
      end
    end
  end
  p:close()
  return monitors
end

-- Fallbacks and GDK scale state
local primary_gdk_scale = 1
local configured_any = false
local x_offset = 0

local connected = get_connected_monitors()

local function same_monitor_set(saved, current)
  if type(saved) ~= "table" or type(saved.outputs) ~= "table" then return false end

  local current_names = {}
  local current_count = 0
  for _, m in ipairs(current) do
    current_names[m.name] = true
    current_count = current_count + 1
  end

  local saved_count = 0
  for _, m in ipairs(saved.outputs) do
    if not m.disabled then
      if not current_names[m.output] then return false end
      saved_count = saved_count + 1
    end
  end

  return saved_count == current_count
end

local saved_layout_path = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/omd/display/layout.lua"
local ok, saved_layout = pcall(dofile, saved_layout_path)
if ok and same_monitor_set(saved_layout, connected) then
  local primary_gdk_scale = 1
  for i, m in ipairs(saved_layout.outputs) do
    if not m.disabled and (m.output:sub(1, 3) == "eDP" or i == 1) then
      primary_gdk_scale = math.max(1, math.floor((tonumber(m.scale) or 1) + 0.5))
      break
    end
  end

  for _, m in ipairs(saved_layout.outputs) do
    if m.disabled then
      hl.monitor({ output = m.output, disabled = true })
    else
      hl.monitor({
        output = m.output,
        mode = m.mode or "preferred",
        position = m.position or "auto",
        scale = tonumber(m.scale) or 1,
        transform = tonumber(m.transform) or 0
      })
    end
  end

  hl.env("GDK_SCALE", tostring(primary_gdk_scale))
  hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
  return
end

for _, m in ipairs(connected) do
  local is_internal = m.name:sub(1, 3) == "eDP"
  local scale = 1.0
  local gdk_scale = 1

  if is_internal then
    -- --- INTERNAL LAPTOP SCREENS ---
    if m.w <= 2000 then
      -- 1080p/1200p Laptop: 1.25x scale is highly readable, interface is neat
      scale = 1.25
      gdk_scale = 1
    elseif m.w <= 3100 then
      -- Retina screens (like MacBook Pro 3024x1964, 2880x1800): 2.0x scale (optimal)
      scale = 2.0
      gdk_scale = 2
    else
      -- 4K Laptop screens: 2.0x scale
      scale = 2.0
      gdk_scale = 2
    end
  else
    -- --- EXTERNAL MONITORS ---
    if m.w <= 2000 then
      -- Standard 1080p external: 1.0x scale
      scale = 1.0
      gdk_scale = 1
    elseif m.w <= 2600 then
      -- 2K/1440p external: 1.25x scale (or 1.0x for some, 1.25x is highly standard for readability)
      scale = 1.25
      gdk_scale = 1
    elseif m.w <= 3840 then
      -- 4K external: 1.5x scale (fractional) or 2.0x depending on size. 1.5x is a perfect compromise.
      scale = 1.5
      gdk_scale = 1
    else
      -- 5K/6K external (Retina): 2.0x scale
      scale = 2.0
      gdk_scale = 2
    end
  end

  -- We track the primary internal screen scaling to drive GDK_SCALE env
  if is_internal or not configured_any then
    primary_gdk_scale = gdk_scale
  end

  -- Apply monitor configuration to Hyprland
  hl.monitor({
    output = m.name,
    mode = "preferred",
    position = x_offset .. "x0",
    scale = scale
  })

  -- Lay monitors side-by-side (adjusting for fractional logic width)
  local logical_width = math.floor(m.w / scale)
  x_offset = x_offset + logical_width
  configured_any = true
end

-- Export primary environment scale
hl.env("GDK_SCALE", tostring(primary_gdk_scale))

-- Wildcard adaptive fallback for safety
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
