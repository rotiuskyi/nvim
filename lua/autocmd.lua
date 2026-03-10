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
autocmd("VimResized", {
  group = "ResizeSplits",
  callback = function()
    vim.cmd("tabdo wincmd =")
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

augroup("ZenOnStartup", { clear = true })
autocmd("VimEnter", {
  group = "ZenOnStartup",
  callback = function()
    local ok, zenmode = pcall(require, "zen-mode")
    if ok then
      zenmode.toggle()
    end
  end,
})

vim.api.nvim_create_user_command("Q", function(opts)
  local ok, zenmode = pcall(require, "zen-mode")
  if ok and vim.g.zen_mode_active then
    zenmode.toggle()
  end

  if opts.bang then
    vim.cmd("quit!")
  else
    vim.cmd("quit")
  end
end, { bang = true })

vim.cmd([[
  cnoreabbrev <expr> q  (getcmdtype() == ':' && getcmdline() ==# 'q'  && exists('g:zen_mode_winid') && win_getid() ==# g:zen_mode_winid)  ? 'Q'  : 'q'
  cnoreabbrev <expr> q! (getcmdtype() == ':' && getcmdline() ==# 'q!' && exists('g:zen_mode_winid') && win_getid() ==# g:zen_mode_winid) ? 'Q!' : 'q!'
]])

augroup("LazyKeepZen", { clear = true })
autocmd("BufWinLeave", {
  group = "LazyKeepZen",
  callback = function(args)
    local ft = vim.api.nvim_get_option_value("filetype", { buf = args.buf })
    if ft ~= "lazy" then
      return
    end

    if vim.g.zen_mode_active then
      return
    end

    local ok, zenmode = pcall(require, "zen-mode")
    if ok then
      zenmode.toggle()
    end
  end,
})
