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
  map("n", "<leader>f", function()
    vim.lsp.buf.format({ async = true })
  end, vim.tbl_extend("force", opts, { desc = "[F]ormat buffer" }))

  if client:supports_method("textDocument/inlayHint") then
    vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
    map("n", "<leader>th", function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr })
    end, vim.tbl_extend("force", opts, { desc = "[T]oggle inlay [H]ints" }))
  end
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

-- Rust: rust-analyzer (rustup component add rust-analyzer, or :MasonInstall rust-analyzer)
-- Resolve the workspace root: walk up to the outermost Cargo.toml that declares
-- a [workspace], so members of a cargo workspace share one rust-analyzer instance.
local function rust_root_dir(fname)
  local dir = vim.fs.dirname(fname)
  local root = nil
  for _, manifest in ipairs(vim.fs.find("Cargo.toml", { path = dir, upward = true, limit = math.huge })) do
    root = root or vim.fs.dirname(manifest)
    local content = table.concat(vim.fn.readfile(manifest), "\n")
    if content:match("%[workspace%]") then
      root = vim.fs.dirname(manifest)
    end
  end
  if root then
    return root
  end
  local proj = vim.fs.find("rust-project.json", { path = dir, upward = true })[1]
  return proj and vim.fs.dirname(proj) or nil
end

-- Prefer a mason-managed rust-analyzer, fall back to the one on PATH (rustup).
local function rust_analyzer_cmd()
  local mason_bin = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin", "rust-analyzer")
  if vim.fn.executable(mason_bin) == 1 then
    return { mason_bin }
  end
  if vim.fn.executable("rust-analyzer") == 1 then
    return { "rust-analyzer" }
  end
  return nil
end

vim.lsp.config("rust_analyzer", {
  cmd = rust_analyzer_cmd() or { "rust-analyzer" },
  filetypes = { "rust" },
  root_dir = function(bufnr, on_dir)
    on_dir(rust_root_dir(vim.api.nvim_buf_get_name(bufnr)))
  end,
  on_attach = on_attach,
  capabilities = capabilities,
  settings = {
    ["rust-analyzer"] = {
      cargo = {
        allFeatures = true,
        loadOutDirsFromCheck = true,
        buildScripts = { enable = true },
      },
      procMacro = { enable = true },
      checkOnSave = true,
      check = {
        command = "clippy",
        extraArgs = { "--no-deps" },
      },
      diagnostics = {
        enable = true,
        experimental = { enable = false },
      },
      imports = {
        granularity = { group = "module" },
        prefix = "self",
      },
      inlayHints = {
        bindingModeHints = { enable = false },
        chainingHints = { enable = true },
        closingBraceHints = { enable = true, minLines = 25 },
        closureReturnTypeHints = { enable = "never" },
        lifetimeElisionHints = { enable = "never", useParameterNames = false },
        maxLength = 25,
        parameterHints = { enable = true },
        reborrowHints = { enable = "never" },
        renderColons = true,
        typeHints = { enable = true, hideClosureInitialization = false, hideNamedConstructor = false },
      },
      lens = {
        enable = true,
        implementations = { enable = true },
        references = { adt = { enable = true }, method = { enable = true } },
      },
      completion = {
        callable = { snippets = "fill_arguments" },
        postfix = { enable = true },
      },
    },
  },
})

-- vim.lsp.config() only registers a config; nothing starts until it is enabled.
local servers = { "lua_ls" }

if rust_analyzer_cmd() then
  table.insert(servers, "rust_analyzer")
end

if vim.fn.executable("avalonia-ls") == 1 then
  table.insert(servers, "avalonia_ls")
end

vim.lsp.enable(servers)

_G.lsp_on_attach = on_attach
_G.lsp_capabilities = capabilities
