local theme_path = vim.fn.expand("~/.local/state/sumika-shell/theme/current/neovim.lua")
local omd_nvim_path = vim.fn.expand("~/.config/omd/config/nvim")

if vim.fn.isdirectory(omd_nvim_path) == 1 then
  vim.opt.runtimepath:prepend(omd_nvim_path)
end

local function load_theme_specs()
  local ok, specs = pcall(dofile, theme_path)
  if ok and type(specs) == "table" then
    return specs
  end

  vim.schedule(function()
    vim.notify("Could not load OMD Neovim theme: " .. theme_path, vim.log.levels.WARN)
  end)
  return {}
end

local function find_colorscheme(specs)
  for _, spec in ipairs(specs) do
    if type(spec) == "table" and spec[1] == "LazyVim/LazyVim" then
      local opts = spec.opts
      if type(opts) == "table" and type(opts.colorscheme) == "string" then
        return opts.colorscheme
      end
    end
  end
end

local last_theme = nil

local function apply_current_theme()
  local specs = load_theme_specs()
  local colorscheme = find_colorscheme(specs)

  if not colorscheme then
    vim.notify("OMD Neovim theme has no LazyVim colorscheme", vim.log.levels.WARN)
    return
  end

  if last_theme == colorscheme and vim.g.colors_name == colorscheme then
    return
  end

  local ok, err = pcall(vim.cmd.colorscheme, colorscheme)
  if ok then
    last_theme = colorscheme
  else
    vim.notify(
      "OMD colorscheme '" .. colorscheme .. "' is not available yet. Run :Lazy sync or restart Neovim. " .. err,
      vim.log.levels.WARN
    )
  end
end

vim.api.nvim_create_user_command("OmarchyThemeReload", apply_current_theme, {})

vim.api.nvim_create_autocmd({ "FocusGained", "VimEnter" }, {
  group = vim.api.nvim_create_augroup("omd-theme", { clear = true }),
  callback = function()
    apply_current_theme()
  end,
})

return load_theme_specs()
