local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

augroup("HighlightYank", { clear = true })
autocmd("TextYankPost", {
  group = "HighlightYank",
  callback = function()
    vim.highlight.on_yank()
  end,
})

augroup("ResizeSplits", { clear = true })
autocmd({ "VimResized", "WinResized" }, {
  group = "ResizeSplits",
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

augroup("RoslynAttach", { clear = true })
autocmd("LspAttach", {
  group = "RoslynAttach",
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.name == "roslyn" then
      if _G.lsp_on_attach then
        _G.lsp_on_attach(client, args.buf)
      end
      client.notify("workspace/didChangeConfiguration", {
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
    end
  end,
})

augroup("RustFormatOnSave", { clear = true })
autocmd("BufWritePre", {
  group = "RustFormatOnSave",
  pattern = "*.rs",
  callback = function(args)
    if #vim.lsp.get_clients({ bufnr = args.buf, name = "rust_analyzer" }) > 0 then
      vim.lsp.buf.format({ bufnr = args.buf, timeout_ms = 3000 })
    end
  end,
  desc = "Format Rust buffers with rustfmt via rust-analyzer",
})

augroup("RustFileSettings", { clear = true })
autocmd("FileType", {
  group = "RustFileSettings",
  pattern = "rust",
  callback = function()
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
    vim.bo.expandtab = true
    vim.bo.commentstring = "// %s"
    vim.opt_local.colorcolumn = "100"
  end,
  desc = "rustfmt-compatible indentation for Rust files",
})

-- virtual_lines renders the cursor line, so the inline virtual text for that
-- line is suppressed in config.lua. That decision is made at render time, and
-- inline text is only rendered when diagnostics change, so re-render it
-- whenever the cursor lands on a different line.
augroup("DiagnosticCursorLine", { clear = true })
autocmd({ "CursorMoved", "DiagnosticChanged" }, {
  group = "DiagnosticCursorLine",
  callback = function(args)
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local previous = vim.b[args.buf].diagnostic_rendered_lnum
    if previous == lnum then
      return
    end
    vim.b[args.buf].diagnostic_rendered_lnum = lnum

    -- only worth re-rendering when the cursor entered or left a flagged line
    local function flagged(line)
      return line and #vim.diagnostic.get(args.buf, { lnum = line - 1 }) > 0
    end
    if flagged(lnum) or flagged(previous) then
      vim.diagnostic.show(nil, args.buf)
    end
  end,
  desc = "Keep inline diagnostics off the line shown as virtual lines",
})

