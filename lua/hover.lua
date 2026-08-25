-- Documentation for the symbol under the cursor, without pressing anything.
--
-- Same idea as lua/inlayhint.lua: what is noise when shown for a whole buffer
-- is useful for the one thing the cursor is on. The window is the one
-- `vim.lsp.buf.hover()` builds, so it renders the server's markdown and closes
-- itself on the next cursor move; here it is only asked for, and never focused,
-- so it cannot interrupt normal movement. `K` still opens it the usual way and
-- does take focus.

local M = {}

local METHOD = "textDocument/hover"

-- Long enough that moving through a line does not flash a window per symbol.
local DELAY_MS = 500

-- Bumped on every cursor move; a scheduled request is dropped once it no longer
-- matches, so only the position the cursor settled on is asked about.
local seq = 0

local CONFIG = {
  silent = true,
  focus = false,
  focusable = true,
  border = "rounded",
  max_width = 100,
  max_height = 20,
  -- diagnostics for the cursor line are drawn underneath it, so the window
  -- takes the space above whenever it fits there
  anchor_bias = "above",
}

-- A symbol has to be under the cursor, not merely on the line: on whitespace or
-- punctuation a server either answers nothing or describes the enclosing
-- expression, which is not what was asked for.
local function on_symbol()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local char = vim.api.nvim_get_current_line():sub(col + 1, col + 1)
  return char ~= "" and vim.fn.match(char, "\\k") >= 0
end

function M.enabled(bufnr)
  return vim.b[bufnr or 0].cursor_hover ~= false
end

function M.update(bufnr)
  seq = seq + 1
  local token = seq

  if not vim.api.nvim_buf_is_valid(bufnr) or not M.enabled(bufnr) then
    return
  end
  if vim.api.nvim_get_current_buf() ~= bufnr or vim.api.nvim_get_mode().mode:find("i") then
    return
  end
  -- inside a floating window the cursor is reading, not navigating
  if vim.api.nvim_win_get_config(0).relative ~= "" then
    return
  end
  if not on_symbol() or #vim.lsp.get_clients({ bufnr = bufnr, method = METHOD }) == 0 then
    return
  end

  vim.defer_fn(function()
    if token == seq and vim.api.nvim_get_current_buf() == bufnr and on_symbol() then
      vim.lsp.buf.hover(vim.deepcopy(CONFIG))
    end
  end, DELAY_MS)
end

function M.toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local on = not M.enabled(bufnr)
  vim.b[bufnr].cursor_hover = on
  if on then
    M.update(bufnr)
  else
    seq = seq + 1
  end
  return on
end

function M.setup()
  local group = vim.api.nvim_create_augroup("CursorHover", { clear = true })

  vim.api.nvim_create_autocmd({ "CursorMoved", "InsertLeave" }, {
    group = group,
    callback = function(args)
      M.update(args.buf)
    end,
    desc = "Show documentation for the symbol under the cursor",
  })

  -- drops whatever is scheduled, so a pending request cannot pop a window open
  -- once typing has started
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    callback = function()
      seq = seq + 1
    end,
    desc = "Hold back documentation while typing",
  })
end

return M
