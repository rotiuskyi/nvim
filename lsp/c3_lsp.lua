-- C3. Install with `:MasonInstall c3-lsp`, or build pherrymason/c3-lsp from
-- source: https://github.com/pherrymason/c3-lsp

-- Prefer a mason-managed binary, fall back to the one on PATH.
local function cmd()
  local mason_bin = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin", "c3lsp")
  if vim.fn.executable(mason_bin) == 1 then
    return { mason_bin }
  end
  return { "c3lsp" }
end

return {
  cmd = cmd(),
  -- .c3, .c3i and .c3t all land on the c3 filetype
  filetypes = { "c3" },
  root_markers = { "project.json", "manifest.json", ".git" },
}
