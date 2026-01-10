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
