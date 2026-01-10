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

