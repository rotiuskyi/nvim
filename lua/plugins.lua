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
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          theme = "nightfox",
          component_separators = { left = "│", right = "│" },
          section_separators = { left = "", right = "" },
          disabled_filetypes = {
            statusline = {},
            winbar = {},
          },
          ignore_focus = {},
          always_divide_middle = true,
          globalstatus = false,
          refresh = {
            statusline = 1000,
            tabline = 1000,
            winbar = 1000,
          },
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = { "filename" },
          lualine_x = { "encoding", "fileformat", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { "filename" },
          lualine_x = { "location" },
          lualine_y = {},
          lualine_z = {},
        },
        tabline = {},
        winbar = {},
        inactive_winbar = {},
        extensions = {},
      })
    end,
  },
  {
    "folke/zen-mode.nvim",
    opts = {
      window = {
        backdrop = 0.95,
        width = 120,
        height = 1,
        options = {},
      },
      plugins = {
        options = {
          enabled = true,
          ruler = false,
          showcmd = false,
          laststatus = 3,
        },
        gitsigns = { enabled = false },
        tmux = { enabled = false },
      },
    },
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
      require("lsp")
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
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        formatting = {
          fields = { "kind", "abbr", "menu" },
          format = function(entry, vim_item)
            local kind_icons = {
              Method = "󰆧",
              Function = "󰊕",
              Constructor = "󰆧",
              Variable = "󰂡",
              Field = "󰇽",
              Property = "󰜢",
              Class = "󰆧",
              Interface = "󰗭",
              Keyword = "󰌋",
            }

            local kind_name = vim_item.kind:match("%S+$") or ""
            local icon = kind_icons[kind_name] or ""
            
            if icon ~= "" then
              vim_item.kind = icon
            else
              vim_item.kind = ""
            end

            local completion_item = entry.completion_item
            local detail = ""

            if completion_item then
              if completion_item.detail then
                detail = completion_item.detail
              end
            end

            if kind_name == "Method" or kind_name == "Function" or kind_name == "Constructor" then
              if detail and detail ~= "" then
                local func_name = vim_item.abbr
                local params = detail:match("%b()") or ""
                local return_type = ""
                
                if detail:match("^%S+") then
                  return_type = detail:match("^(%S+)%s+" .. func_name) or detail:match("^(%S+)%s+%(") or ""
                end
                
                if params ~= "" then
                  params = params:gsub("%s+", " ")
                  local max_param_width = 60
                  if #params > max_param_width then
                    params = params:sub(1, max_param_width) .. "...)"
                  end
                  vim_item.abbr = func_name .. params
                end
                
                if return_type ~= "" and return_type ~= func_name then
                  vim_item.menu = "→ " .. return_type
                else
                  vim_item.menu = ""
                end
              else
                vim_item.menu = ""
              end
            elseif kind_name == "Variable" or kind_name == "Field" or kind_name == "Property" then
              if detail and detail ~= "" then
                local var_type = detail:match("^%s*(%S+)") or detail
                local max_width = 35
                if #var_type > max_width then
                  var_type = var_type:sub(1, max_width) .. "..."
                end
                vim_item.menu = var_type
              else
                vim_item.menu = ""
              end
            else
              vim_item.menu = ""
            end

            return vim_item
          end,
        },
        sources = cmp.config.sources({
          { name = "nvim_lsp", priority = 1000, max_item_count = 20 },
          { name = "luasnip", priority = 750 },
        }, {
          { name = "buffer", priority = 500, keyword_length = 4, max_item_count = 5 },
          { name = "path", priority = 250 },
        }),
        completion = {
          keyword_length = 1,
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
      })
    end,
  },
})
