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
})

