-- ╭────────────────────────────────────────────────────────────╮
-- │                      Global Settings                       │
-- ╰────────────────────────────────────────────────────────────╯

vim.g.base46_cache = vim.fn.stdpath("data") .. "/base46/"
vim.g.mapleader = " "

-- ╭────────────────────────────────────────────────────────────╮
-- │                 Bootstrap lazy.nvim plugin                 │
-- ╰────────────────────────────────────────────────────────────╯

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    repo,
    "--branch=stable",
    lazypath,
  })
end

vim.opt.rtp:prepend(lazypath)

-- ╭────────────────────────────────────────────────────────────╮
-- │                     Lazy.nvim Config                       │
-- ╰────────────────────────────────────────────────────────────╯

local lazy_config = require("configs.lazy")

require("lazy").setup({
  -- Core framework
  {
    "NvChad/NvChad",
    lazy = false,
    branch = "v2.5",
    import = "nvchad.plugins",
  },

  -- Theme
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
  },

  -- Custom plugins
  {
    import = "plugins",
  },
}, lazy_config)

-- ╭────────────────────────────────────────────────────────────╮
-- │                      Theme and UI                          │
-- ╰────────────────────────────────────────────────────────────╯

-- Load base46 cached theme files
dofile(vim.g.base46_cache .. "defaults")
dofile(vim.g.base46_cache .. "statusline")

-- Apply Catppuccin theme settings
require("catppuccin").setup({
  flavour = "mocha",
  no_italic = false,
  no_bold = false,
  no_underline = false,
  styles = {
    comments = { "italic" },
  },
  default_integrations = true,
})

vim.cmd.colorscheme("catppuccin")

-- ╭────────────────────────────────────────────────────────────╮
-- │                  Core Configurations                       │
-- ╰────────────────────────────────────────────────────────────╯

require("options")
require("nvchad.autocmds")

-- Load mappings after startup
vim.schedule(function()
  require("mappings")
end)