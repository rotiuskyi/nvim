local map = vim.keymap.set

local on_attach = function(client, bufnr)
  local opts = { buffer = bufnr, remap = false }

  map("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "[G]oto [D]efinition" }))
  map("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "Hover Documentation" }))
  map("n", "<leader>ws", vim.lsp.buf.workspace_symbol, vim.tbl_extend("force", opts, { desc = "[W]orkspace [S]ymbol" }))
  map("n", "<leader>ca", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "[C]ode [A]ction" }))
  map("n", "<leader>rr", vim.lsp.buf.references, vim.tbl_extend("force", opts, { desc = "[R]eferences" }))
  map("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "[R]e[N]ame" }))
  map("i", "<C-h>", vim.lsp.buf.signature_help, vim.tbl_extend("force", opts, { desc = "Signature Help" }))
end

local capabilities = vim.lsp.protocol.make_client_capabilities()
local cmp_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if cmp_ok then
  capabilities = vim.tbl_deep_extend("force", capabilities, cmp_nvim_lsp.default_capabilities())
end

-- XAML / Avalonia: filetype and syntax for .axaml
vim.filetype.add({ extension = { axaml = "axaml" } })
vim.api.nvim_create_autocmd("FileType", {
  pattern = "axaml",
  callback = function()
    vim.bo.syntax = "xml"
  end,
  desc = "Use XML syntax for Avalonia XAML",
})

-- Avalonia XAML LSP (avalonia-ls) — completions, formatting; install separately
-- e.g. from source: https://github.com/SaverinOnRails/ls-for-avalonia (just install)
-- or AUR: yay -S avalonia-ls-git
local function avalonia_root_dir()
  local proj = vim.fs.find({ "*.csproj", "*.fsproj" }, { upward = true })[1]
  if proj then
    return vim.fs.dirname(proj)
  end
  return vim.fn.getcwd()
end

if vim.fn.executable("avalonia-ls") == 1 then
  vim.lsp.config("avalonia_ls", {
    cmd = { "avalonia-ls" },
    filetypes = { "axaml" },
    root_dir = avalonia_root_dir,
    on_attach = on_attach,
    capabilities = capabilities,
  })
end

vim.lsp.config("lua_ls", {
  on_attach = on_attach,
  capabilities = capabilities,
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      workspace = { checkThirdParty = false },
      telemetry = { enable = false },
    },
  },
})

_G.lsp_on_attach = on_attach
_G.lsp_capabilities = capabilities
