local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

autocmd("TextYankPost", {
  group = augroup("YankHighlight", { clear = true }),
  pattern = "*",
  callback = function()
    vim.hl.on_yank({ timeout = 170 })
  end,
})

autocmd({ "VimResized", "WinResized" }, {
  group = augroup("ResizeSplits", { clear = true }),
  callback = function(args)
    if args.event == "VimResized" then
      vim.cmd("tabdo wincmd =")
    end
    -- inline diagnostics are truncated to the room left on each line, so the
    -- available width changed with the window
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local buf = vim.api.nvim_win_get_buf(win)
      if #vim.diagnostic.get(buf) > 0 then
        vim.diagnostic.show(nil, buf)
      end
    end
  end,
})

-- roslyn.nvim starts the server itself, so the settings it should run with have
-- to be pushed after the fact. Keymaps come from the LspAttach hook in lua/lsp.lua.
autocmd("LspAttach", {
  group = augroup("RoslynSettings", { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client or client.name ~= "roslyn" then
      return
    end
    client:notify("workspace/didChangeConfiguration", {
      settings = {
        ["csharp|background_analysis"] = {
          ["background_analysis.dotnet_analyzer_diagnostics_scope"] = "fullSolution",
          ["background_analysis.dotnet_compiler_diagnostics_scope"] = "fullSolution",
        },
        ["csharp|inlay_hints"] = {
          csharp_enable_inlay_hints_for_implicit_object_creation = true,
          csharp_enable_inlay_hints_for_implicit_variable_types = true,
          csharp_enable_inlay_hints_for_lambda_parameter_types = true,
          csharp_enable_inlay_hints_for_types = true,
          dotnet_enable_inlay_hints_for_indexer_parameters = true,
          dotnet_enable_inlay_hints_for_literal_parameters = true,
          dotnet_enable_inlay_hints_for_object_creation_parameters = true,
          dotnet_enable_inlay_hints_for_other_parameters = true,
          dotnet_enable_inlay_hints_for_parameters = true,
        },
        ["csharp|completion"] = {
          dotnet_provide_regex_completions = true,
          dotnet_show_completion_items_from_unimported_namespaces = true,
          dotnet_show_name_completion_suggestions = true,
        },
        ["csharp|code_lens"] = {
          dotnet_enable_references_code_lens = true,
          dotnet_enable_tests_code_lens = true,
        },
        ["csharp|formatting"] = {
          dotnet_organize_imports_on_format = true,
        },
        ["csharp|symbol_search"] = {
          dotnet_search_reference_assemblies = true,
        },
      },
    })
  end,
})

autocmd("BufWritePre", {
  group = augroup("RustFormatOnSave", { clear = true }),
  pattern = "*.rs",
  callback = function(args)
    if #vim.lsp.get_clients({ bufnr = args.buf, name = "rust-analyzer" }) > 0 then
      vim.lsp.buf.format({ bufnr = args.buf, timeout_ms = 3000 })
    end
  end,
  desc = "Format Rust buffers with rustfmt via rust-analyzer",
})

autocmd("FileType", {
  group = augroup("RustFileSettings", { clear = true }),
  pattern = "rust",
  -- indentation already matches rustfmt globally; only the line length differs
  callback = function()
    vim.opt_local.colorcolumn = "100"
  end,
  desc = "rustfmt's line length for Rust files",
})

-- Inline diagnostics are laid out against the room left on the screen line, and
-- that measurement can go stale in two ways.
--
-- virtual_lines renders the cursor line, so the inline text for that line is
-- suppressed in config.lua. That decision is made at render time, and inline
-- text is only redrawn when diagnostics change, so the line has to be redrawn
-- when the cursor arrives at or leaves it.
--
-- A server can also answer in more than one namespace -- rust-analyzer sends
-- push and pull diagnostics separately -- and each one renders on its own,
-- unable to see the other's messages when working out how much room is left.
-- Redrawing once they have all landed settles the line.
local reshow_pending = {}

local function reshow(bufnr)
  if reshow_pending[bufnr] then
    return
  end
  reshow_pending[bufnr] = true
  -- long enough to coalesce a burst of namespaces answering one after another
  vim.defer_fn(function()
    reshow_pending[bufnr] = nil
    if vim.api.nvim_buf_is_valid(bufnr) then
      -- redraws every namespace, which is the point: each is re-measured
      -- knowing what the others put on the line
      vim.diagnostic.show(nil, bufnr)
    end
  end, 150)
end

augroup("DiagnosticCursorLine", { clear = true })

autocmd("DiagnosticChanged", {
  group = "DiagnosticCursorLine",
  callback = function(args)
    reshow(args.buf)
  end,
  desc = "Re-measure inline diagnostics once every namespace has answered",
})

autocmd("CursorMoved", {
  group = "DiagnosticCursorLine",
  callback = function(args)
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local previous = vim.b[args.buf].diagnostic_rendered_lnum
    if previous == lnum then
      return
    end
    vim.b[args.buf].diagnostic_rendered_lnum = lnum

    -- only worth redrawing when the cursor entered or left a line some
    -- diagnostic covers; a diagnostic can span lines, so its start is not enough
    local function flagged(line)
      if not line then
        return false
      end
      local target = line - 1
      for _, d in ipairs(vim.diagnostic.get(args.buf)) do
        if target >= d.lnum and target <= (d.end_lnum or d.lnum) then
          return true
        end
      end
      return false
    end
    if flagged(lnum) or flagged(previous) then
      vim.diagnostic.show(nil, args.buf)
    end
  end,
  desc = "Keep inline diagnostics off the line shown as virtual lines",
})
