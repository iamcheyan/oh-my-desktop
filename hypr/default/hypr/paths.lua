-- Shared path constants for Sumika Shell's Hyprland Lua modules.
-- Lua files loaded with require() have separate local scopes, so modules that
-- need these paths import this table instead of repeating os.getenv() lookups.

local home = os.getenv("HOME")
local config_home = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")
local state_home = os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")
local data_home = os.getenv("XDG_DATA_HOME") or (home .. "/.local/share")
local runtime_dir = os.getenv("XDG_RUNTIME_DIR") or ("/run/user/" .. tostring(os.getenv("UID") or "1000"))

-- Repository root is exported by the Sumika Shell session wrapper.
local root = os.getenv("SUMIKA_SHELL_ROOT")
if not root or root == "" then
  root = "/dev/null/SUMIKA_SHELL_ROOT_UNSET"
end

-- Resolve symlinks so that IPC paths match regardless of whether the session
-- Normalize the path so IPC instance discovery uses one stable spelling.
-- This is a one-time readlink call during config load.
if root and root ~= "" then
  local pipe = io.popen("readlink -f '" .. root .. "' 2>/dev/null")
  if pipe then
    local resolved = pipe:read("*l")
    pipe:close()
    if resolved and resolved ~= "" and resolved ~= root then
      root = resolved
    end
  end
end

return {
  -- Sumika Shell path contract (canonical)
  root = root,
  config_home = os.getenv("SUMIKA_SHELL_CONFIG_HOME") or (config_home .. "/sumika-shell"),
  state_home = os.getenv("SUMIKA_SHELL_STATE_HOME") or (state_home .. "/sumika-shell"),
  data_home = os.getenv("SUMIKA_SHELL_DATA_HOME") or (data_home .. "/sumika-shell"),
  runtime_dir = os.getenv("SUMIKA_SHELL_RUNTIME_DIR") or (runtime_dir .. "/sumika-shell"),

  home = home,
  -- Raw XDG dirs for callers that still need them directly
  xdg_config_home = config_home,
  xdg_state_home = state_home,
}
