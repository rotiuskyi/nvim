-- Per-server settings live in the lsp/ directory, one file per server, which
-- Neovim picks up by name. What every server shares stays here.

local inlayhint = require("inlayhint")
inlayhint.setup()

local hover = require("hover")
hover.setup()

-- Avalonia XAML: .axaml is not a filetype Neovim knows about
vim.filetype.add({ extension = { axaml = "axaml" } })
vim.api.nvim_create_autocmd("FileType", {
  pattern = "axaml",
  callback = function()
    vim.bo.syntax = "xml"
  end,
  desc = "Use XML syntax for Avalonia XAML",
})

-- Applies to every server, roslyn.nvim's included.
vim.lsp.config("*", {
  capabilities = require("blink.cmp").get_lsp_capabilities(),
})

vim.lsp.enable({ "lua_ls", "rust-analyzer" })

if vim.fn.executable("avalonia-ls") == 1 then
  vim.lsp.enable("avalonia_ls")
end

-- Keymaps hang off LspAttach instead of a per-server on_attach, so a server
-- that configures itself from its own plugin -- roslyn does -- gets them too.
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("LspKeymaps", { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then
      return
    end

    local function map(lhs, rhs, desc)
      vim.keymap.set("n", lhs, rhs, { buffer = args.buf, remap = false, desc = desc })
    end

    map("gd", vim.lsp.buf.definition, "[G]oto [D]efinition")
    map("K", vim.lsp.buf.hover, "Hover Documentation")
    map("<leader>ws", vim.lsp.buf.workspace_symbol, "[W]orkspace [S]ymbol")
    map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction")
    map("<leader>rr", vim.lsp.buf.references, "[R]eferences")
    map("<leader>rn", vim.lsp.buf.rename, "[R]e[N]ame")
    map("<leader>fo", function()
      vim.lsp.buf.format({ async = true })
    end, "[Fo]rmat buffer")
    map("<leader>tk", function()
      hover.toggle(args.buf)
    end, "[T]oggle hover on cursor hold")

    if client:supports_method("textDocument/inlayHint") then
      -- Neovim's own renderer only knows whole buffers. Hints are drawn for the
      -- line under the cursor instead; see lua/inlayhint.lua.
      vim.lsp.inlay_hint.enable(false, { bufnr = args.buf })
      map("<leader>th", function()
        inlayhint.toggle(args.buf)
      end, "[T]oggle inlay [H]ints")
    end
  end,
  desc = "LSP keymaps and cursor-scoped hints",
})
