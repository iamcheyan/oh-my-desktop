-- Read config values from sumika.json.
-- Provides typed accessors so Hyprland Lua configs can be data-driven.
-- Usage:
--   local cfg = require("default.hypr.config")
--   hl.config({ input = { kb_layout = cfg.get("input.keyboard.kbLayout", "jp") } })

local M = {}

local function config_path()
  local config_home = os.getenv("SUMIKA_SHELL_CONFIG_HOME")
    or (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/sumika-shell"
  return config_home .. "/sumika.json"
end

-- Cache the parsed config so we only read+parse once per reload.
local _cache = nil

function M._clear_cache()
  _cache = nil
end

-- Minimal JSON parser for the subset we need (objects, strings, numbers, booleans, null, arrays)
-- Returns { value, pos } or nil on error.
local function json_parse(str, pos)
  pos = pos or 1
  while pos <= #str do
    local c = str:sub(pos, pos)
    if c == " " or c == "\t" or c == "\n" or c == "\r" then
      pos = pos + 1
    elseif c == "{" then
      local obj = {}
      pos = pos + 1
      local first = true
      while pos <= #str do
        while pos <= #str and (str:sub(pos, pos) == " " or str:sub(pos, pos) == "\t" or str:sub(pos, pos) == "\n" or str:sub(pos, pos) == "\r") do
          pos = pos + 1
        end
        if str:sub(pos, pos) == "}" then
          return obj, pos + 1
        end
        if not first then
          if str:sub(pos, pos) ~= "," then return nil, pos end
          pos = pos + 1
        end
        first = false
        -- Parse key string
        local k, kpos = json_parse(str, pos)
        if not k then return nil, kpos end
        pos = kpos
        while pos <= #str and (str:sub(pos, pos) == " " or str:sub(pos, pos) == "\t" or str:sub(pos, pos) == "\n" or str:sub(pos, pos) == "\r") do
          pos = pos + 1
        end
        if str:sub(pos, pos) ~= ":" then return nil, pos end
        pos = pos + 1
        local v, vpos = json_parse(str, pos)
        if v == nil then return nil, vpos end
        pos = vpos
        obj[k] = v
      end
    elseif c == "[" then
      local arr = {}
      pos = pos + 1
      local first = true
      while pos <= #str do
        while pos <= #str and (str:sub(pos, pos) == " " or str:sub(pos, pos) == "\t" or str:sub(pos, pos) == "\n") do
          pos = pos + 1
        end
        if str:sub(pos, pos) == "]" then
          return arr, pos + 1
        end
        if not first then
          if str:sub(pos, pos) ~= "," then return nil, pos end
          pos = pos + 1
        end
        first = false
        local v, vpos = json_parse(str, pos)
        if v == nil then return nil, vpos end
        pos = vpos
        table.insert(arr, v)
      end
    elseif c == '"' then
      local s = {}
      pos = pos + 1
      while pos <= #str do
        local ch = str:sub(pos, pos)
        if ch == '"' then
          return table.concat(s), pos + 1
        elseif ch == "\\" then
          pos = pos + 1
          local esc = str:sub(pos, pos)
          if esc == '"' or esc == "\\" or esc == "/" then
            table.insert(s, esc)
          elseif esc == "n" then
            table.insert(s, "\n")
          elseif esc == "t" then
            table.insert(s, "\t")
          elseif esc == "u" then
            -- Skip unicode escapes (simplified)
            table.insert(s, "?")
            pos = pos + 4
          else
            table.insert(s, esc)
          end
          pos = pos + 1
        else
          table.insert(s, ch)
          pos = pos + 1
        end
      end
    elseif c == "t" and str:sub(pos, pos + 3) == "true" then
      return true, pos + 4
    elseif c == "f" and str:sub(pos, pos + 4) == "false" then
      return false, pos + 5
    elseif c == "n" and str:sub(pos, pos + 3) == "null" then
      return nil, pos + 4
    elseif c == "-" or (c >= "0" and c <= "9") then
      local _, e = str:find("^-?[0-9]+%.?[0-9]*([eE][+-]?[0-9]+)?", pos)
      if e then
        return tonumber(str:sub(pos, e)), e + 1
      end
      return nil, pos
    else
      return nil, pos
    end
  end
  return nil, pos
end

local function load_config()
  if _cache then return _cache end
  local path = config_path()
  local f = io.open(path, "r")
  if not f then
    _cache = {}
    return _cache
  end
  local content = f:read("*a")
  f:close()
  local ok, result = pcall(function()
    local obj, _ = json_parse(content, 1)
    return obj or {}
  end)
  if ok and type(result) == "table" then
    _cache = result
  else
    _cache = {}
  end
  return _cache
end

-- Navigate a dotted path into the config object.
local function resolve(obj, key)
  if not obj or type(obj) ~= "table" then return nil end
  for part in key:gmatch("[^.]+") do
    if type(obj) ~= "table" then return nil end
    obj = obj[part]
  end
  return obj
end

-- Get a value from sumika.json by dotted key path.
-- Returns `default` if the key is missing or null.
function M.get(key, default)
  local config = load_config()
  local val = resolve(config, key)
  if val == nil then return default end
  return val
end

-- Get a boolean value.
function M.getBool(key, default)
  local val = M.get(key, default)
  if type(val) == "boolean" then return val end
  if type(val) == "string" then
    if val == "true" then return true end
    if val == "false" then return false end
  end
  return default
end

-- Get a numeric value.
function M.getNum(key, default)
  local val = M.get(key, default)
  if type(val) == "number" then return val end
  if type(val) == "string" then
    local n = tonumber(val)
    if n then return n end
  end
  return default
end

-- Get a string value.
function M.getString(key, default)
  local val = M.get(key, default)
  if type(val) == "string" then return val end
  return tostring(val) or default
end

-- Get an array value (returns a Lua table).
function M.getArray(key, default)
  local val = M.get(key, default)
  if type(val) == "table" then return val end
  return default
end

-- Get a table value (from a JSON object).
function M.getTable(key, default)
  local val = M.get(key, default)
  if type(val) == "table" then return val end
  return default
end

return M
