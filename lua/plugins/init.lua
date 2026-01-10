require("lazy").setup({
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim" },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").setup({})
    end,
  },
  {
    "EdenEast/nightfox.nvim",
    config = function()
      require("nightfox").setup({})
      vim.cmd("colorscheme nightfox")
    end,
  },
  {
    "seblyng/roslyn.nvim",
    opts = {
      filewatching = "auto",
      choose_target = nil,
      ignore_target = nil,
      broad_search = false,
      lock_target = false,
      silent = false,
    },
    config = function()
      -- Override cmd to use correct Mason path (vim.fn.executable doesn't work with .cmd on Windows)
      local sysname = vim.uv.os_uname().sysname:lower()
      local iswin = not not (sysname:find("windows") or sysname:find("mingw"))
      local roslyn_bin = iswin and "roslyn.cmd" or "roslyn"
      local mason_bin = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin", roslyn_bin)
      local mason_exists = vim.fn.filereadable(mason_bin) == 1

      if mason_exists then
        local cmd = {
          mason_bin,
          "--logLevel=Information",
          "--extensionLogDirectory=" .. vim.fs.dirname(vim.lsp.log.get_filename()),
          "--stdio",
        }
        vim.lsp.config("roslyn", { cmd = cmd })
      end
    end,
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      require("core.lsp")
    end,
  },
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    config = function()
      require("mason").setup({
        registries = {
          "github:mason-org/mason-registry",
          "github:Crashdummyy/mason-registry",
        },
      })
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {},
        automatic_enable = false,
      })
    end,
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      require("core.cmp")
    end,
  },
})

