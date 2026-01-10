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
              Text = "󰉿",
              Method = "󰆧",
              Function = "󰊕",
              Constructor = "󰆧",
              Field = "󰇽",
              Variable = "󰂡",
              Class = "󰆧",
              Interface = "󰗭",
              Module = "󰏗",
              Property = "󰜢",
              Unit = "󰑭",
              Value = "󰎠",
              Enum = "󰒻",
              Keyword = "󰌋",
              Snippet = "󰆐",
              Color = "󰏘",
              File = "󰈔",
              Reference = "󰈇",
              Folder = "󰉋",
              EnumMember = "󰒻",
              Constant = "󰏿",
              Struct = "󰆧",
              Event = "󰆧",
              Operator = "󰆕",
              TypeParameter = "󰅲",
            }

            vim_item.kind = string.format("%s %s", kind_icons[vim_item.kind] or "", vim_item.kind or "")

            local source_name = ({
              nvim_lsp = "[LSP]",
              luasnip = "[Snippet]",
              buffer = "[Buffer]",
              path = "[Path]",
            })[entry.source.name] or ""

            local detail = ""
            if entry.completion_item then
              if entry.completion_item.detail then
                detail = entry.completion_item.detail
              end
              if entry.completion_item.documentation then
                local doc = entry.completion_item.documentation
                if type(doc) == "string" then
                  detail = detail ~= "" and (detail .. " | " .. doc) or doc
                elseif type(doc) == "table" and doc.value then
                  detail = detail ~= "" and (detail .. " | " .. doc.value) or doc.value
                end
              end
            end

            if detail ~= "" then
              vim_item.menu = string.format("%s %s", source_name, detail)
            else
              vim_item.menu = source_name
            end

            return vim_item
          end,
        },
        sources = cmp.config.sources({
          { name = "nvim_lsp", priority = 1000 },
          { name = "luasnip", priority = 750 },
        }, {
          { name = "buffer", priority = 500, keyword_length = 3 },
          { name = "path", priority = 250 },
        }),
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
      })
    end,
  },
})
