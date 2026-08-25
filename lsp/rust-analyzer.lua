-- Install with `rustup component add rust-analyzer` or `:MasonInstall rust-analyzer`.

-- Prefer a mason-managed binary, fall back to the one on PATH.
local function cmd()
  local mason_bin = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin", "rust-analyzer")
  if vim.fn.executable(mason_bin) == 1 then
    return { mason_bin }
  end
  return { "rust-analyzer" }
end

-- root_markers would stop at the nearest Cargo.toml, which splits a cargo
-- workspace into one rust-analyzer per member. Walk up instead and keep the
-- outermost manifest that declares a [workspace].
local function workspace_root(fname)
  local dir = vim.fs.dirname(fname)
  local root = nil
  for _, manifest in ipairs(vim.fs.find("Cargo.toml", { path = dir, upward = true, limit = math.huge })) do
    root = root or vim.fs.dirname(manifest)
    if table.concat(vim.fn.readfile(manifest), "\n"):match("%[workspace%]") then
      root = vim.fs.dirname(manifest)
    end
  end
  if root then
    return root
  end
  local project = vim.fs.find("rust-project.json", { path = dir, upward = true })[1]
  return project and vim.fs.dirname(project) or nil
end

return {
  cmd = cmd(),
  filetypes = { "rust" },
  root_dir = function(bufnr, on_dir)
    on_dir(workspace_root(vim.api.nvim_buf_get_name(bufnr)))
  end,
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
}
