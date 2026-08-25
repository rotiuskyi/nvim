-- Plugins are managed by vim.pack, Neovim's own package manager. There is no
-- bootstrap step and no lock file: vim.pack.add clones what is missing on
-- startup, and `:lua vim.pack.update()` opens a confirmation buffer with the
-- changelog before pulling anything.

-- 1. colours
vim.pack.add({
  { src = "https://github.com/folke/tokyonight.nvim" },
})

require("tokyonight").setup({})

-- 2. status line
vim.pack.add({
  { src = "https://github.com/nvim-tree/nvim-web-devicons" },
  { src = "https://github.com/nvim-lualine/lualine.nvim" },
})

require("lualine").setup({
  options = {
    theme = "tokyonight",
    component_separators = { left = "│", right = "│" },
    section_separators = { left = "", right = "" },
  },
  sections = {
    lualine_a = { "mode" },
    lualine_b = { "branch", "diff", "diagnostics" },
    lualine_c = { "filename" },
    lualine_x = { "encoding", "fileformat", "filetype" },
    lualine_y = { "progress" },
    lualine_z = { "location" },
  },
})

-- 3. language server installer
vim.pack.add({
  { src = "https://github.com/mason-org/mason.nvim" },
})

require("mason").setup({
  registries = {
    "github:mason-org/mason-registry",
    -- carries roslyn, the C# server roslyn.nvim drives
    "github:Crashdummyy/mason-registry",
  },
})

-- 4. pickers
vim.pack.add({
  { src = "https://github.com/ibhagwan/fzf-lua" },
})

local fzf_actions = require("fzf-lua.actions")
require("fzf-lua").setup({
  winopts = { backdrop = 85 },
  keymap = {
    builtin = {
      ["<C-f>"] = "preview-page-down",
      ["<C-b>"] = "preview-page-up",
      ["<C-p>"] = "toggle-preview",
    },
    fzf = {
      ["ctrl-a"] = "toggle-all",
      ["ctrl-t"] = "first",
      ["ctrl-g"] = "last",
      ["ctrl-d"] = "half-page-down",
      ["ctrl-u"] = "half-page-up",
    },
  },
  actions = {
    files = {
      ["ctrl-q"] = fzf_actions.file_sel_to_qf,
      ["ctrl-n"] = fzf_actions.toggle_ignore,
      ["ctrl-h"] = fzf_actions.toggle_hidden,
      ["enter"] = fzf_actions.file_edit_or_qf,
    },
  },
})

-- 5. completion
vim.pack.add({
  { src = "https://github.com/saghen/blink.cmp", version = vim.version.range("^1") },
})

require("blink.cmp").setup({
  fuzzy = { implementation = "prefer_rust_with_warning" },
  signature = { enabled = true },
  keymap = {
    preset = "default",
    ["<C-space>"] = {},
    ["<C-p>"] = {},
    -- Enter accepts the highlighted item and Tab walks the list, the way the
    -- previous nvim-cmp setup behaved. Both fall through when the menu is
    -- closed, so Enter still breaks a line and Tab still indents.
    ["<CR>"] = { "accept", "fallback" },
    ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
    ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
    ["<C-y>"] = { "show", "show_documentation", "hide_documentation" },
    ["<C-n>"] = { "select_and_accept" },
    ["<C-k>"] = { "select_prev", "fallback" },
    ["<C-j>"] = { "select_next", "fallback" },
    ["<C-b>"] = { "scroll_documentation_down", "fallback" },
    ["<C-f>"] = { "scroll_documentation_up", "fallback" },
    ["<C-l>"] = { "snippet_forward", "fallback" },
    ["<C-h>"] = { "snippet_backward", "fallback" },
  },

  appearance = {
    nerd_font_variant = "normal",
  },

  completion = {
    documentation = {
      auto_show = true,
      auto_show_delay_ms = 200,
    },
  },

  cmdline = {
    keymap = {
      preset = "inherit",
      ["<CR>"] = { "accept_and_enter", "fallback" },
    },
  },

  sources = { default = { "lsp" } },
})

-- 6. syntax
vim.pack.add({
  { src = "https://github.com/nvim-treesitter/nvim-treesitter" },
})

local treesitter = require("nvim-treesitter")
treesitter.setup({})

local parsers = { "rust", "toml", "ron", "lua", "vim", "vimdoc", "c_sharp", "xml", "markdown", "markdown_inline" }
local installed = treesitter.get_installed()
local missing = vim.tbl_filter(function(lang)
  return not vim.tbl_contains(installed, lang)
end, parsers)
if #missing > 0 then
  treesitter.install(missing)
end

-- the main branch installs parsers but never starts a highlighter itself
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("TreesitterHighlight", { clear = true }),
  callback = function(args)
    local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
    if not lang then
      return
    end
    if pcall(vim.treesitter.start, args.buf, lang) then
      vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
  desc = "Enable treesitter highlighting when a parser is available",
})

-- 7. C#
vim.pack.add({
  { src = "https://github.com/seblyng/roslyn.nvim" },
})

require("roslyn").setup({
  filewatching = "auto",
  broad_search = false,
  lock_target = false,
  silent = false,
})

local roslyn_bin = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin", "roslyn")
if vim.fn.filereadable(roslyn_bin) == 1 then
  vim.lsp.config("roslyn", {
    cmd = {
      roslyn_bin,
      "--logLevel=Information",
      "--extensionLogDirectory=" .. vim.fs.dirname(vim.lsp.log.get_filename()),
      "--stdio",
    },
  })
end

-- 8. Cargo.toml
vim.pack.add({
  { src = "https://github.com/nvim-lua/plenary.nvim" },
  { src = "https://github.com/saecki/crates.nvim", version = "stable" },
})

require("crates").setup({
  completion = { crates = { enabled = true } },
  -- crates.nvim answers as an in-process language server, so its completions
  -- and hovers arrive through blink.cmp's lsp source with nothing to wire up
  lsp = { enabled = true, actions = true, completion = true, hover = true },
})

-- 9. distraction-free editing
vim.pack.add({
  { src = "https://github.com/folke/zen-mode.nvim" },
})

require("zen-mode").setup({
  window = { backdrop = 0.95, width = 120, height = 1 },
  plugins = {
    options = { enabled = true, ruler = false, showcmd = false, laststatus = 3 },
    gitsigns = { enabled = false },
    tmux = { enabled = false },
  },
})
