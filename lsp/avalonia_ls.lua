-- Avalonia XAML. Install separately, e.g. from source:
-- https://github.com/SaverinOnRails/ls-for-avalonia (just install)

-- root_markers are matched literally -- "*.csproj" never matches anything --
-- so the project file is looked up by hand.
local function project_root(fname)
  local dir = vim.fs.dirname(fname)
  local project = vim.fs.find(function(name)
    return name:match("%.csproj$") or name:match("%.fsproj$")
  end, { path = dir, upward = true, type = "file" })[1]
  if project then
    return vim.fs.dirname(project)
  end
  return vim.fs.root(dir, { ".git" })
end

return {
  cmd = { "avalonia-ls" },
  filetypes = { "axaml" },
  root_dir = function(bufnr, on_dir)
    on_dir(project_root(vim.api.nvim_buf_get_name(bufnr)))
  end,
}
