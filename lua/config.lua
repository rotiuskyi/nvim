vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.guicursor = "i:block"
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.colorcolumn = "80"
vim.opt.listchars = "tab: ,multispace:|   ,eol:󰌑"
vim.opt.winborder = "rounded"
vim.opt.clipboard = "unnamedplus"

vim.opt.mouse = "a"
vim.opt.ignorecase = true
vim.opt.smartcase = true
-- every match of the current search stays highlighted, the way VSCode's find
-- box marks them; <Esc> clears it (see lua/keymap.lua)
vim.opt.hlsearch = true
vim.opt.wrap = false
vim.opt.breakindent = true
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Diagnostics
--
-- Long messages used to run past the right edge of the window. Inline virtual
-- text is collapsed to a single line and cut to the room actually left on that
-- screen line, while the full message is rendered as virtual lines under the
-- cursor line.

local ELLIPSIS = "…"

local VIRTUAL_TEXT_PREFIX = "●"
local VIRTUAL_TEXT_SPACING = 2
local VIRTUAL_TEXT_SEVERITY = { min = vim.diagnostic.severity.WARN }

-- Hints are dropped from the virtual lines. rust-analyzer reports a warning and
-- its suggestion as two diagnostics anchored at different columns, and the tree
-- Neovim draws orders every diagnostic on the line by column, which pulls those
-- pairs apart and interleaves them with each other. The suggestions are still
-- reachable through the diagnostic float on <leader>e.
local VIRTUAL_LINES_SEVERITY = { min = vim.diagnostic.severity.INFO }

-- Below this many columns of free space the inline message is dropped entirely:
-- the sign column still flags the line, and moving onto it shows the full text.
local MIN_VIRTUAL_TEXT_WIDTH = 12

-- rust-analyzer appends the lint a warning came from, e.g.
-- "`#[warn(unused_mut)]` (part of `#[warn(unused)]`) on by default". It repeats
-- for every warning and says nothing the message does not already say.
local function useful_lines(message)
  local lines = {}
  for line in (message .. "\n"):gmatch("([^\n]*)\n") do
    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    if line ~= "" and not line:match("^`?#%[") then
      table.insert(lines, line)
    end
  end
  return lines
end

local function truncate(text, width)
  if width < 1 or vim.fn.strdisplaywidth(text) <= width then
    return text
  end
  local out = vim.fn.strcharpart(text, 0, width - 1)
  while vim.fn.strchars(out) > 1 and vim.fn.strdisplaywidth(out) > width - 1 do
    out = vim.fn.strcharpart(out, 0, vim.fn.strchars(out) - 1)
  end
  return out .. ELLIPSIS
end

local function cursor_lnum(bufnr)
  local win = vim.fn.bufwinid(bufnr or vim.api.nvim_get_current_buf())
  if win == -1 then
    return nil
  end
  return vim.api.nvim_win_get_cursor(win)[1] - 1
end

-- Both handlers group diagnostics by the line they start on. vim.diagnostic.get()
-- cannot be used for that: its lnum filter matches anything whose range covers
-- the line, which is a different set as soon as a diagnostic spans lines.
local function starting_on(bufnr, lnum, severity)
  local count = 0
  for _, d in ipairs(vim.diagnostic.get(bufnr, { severity = severity })) do
    if d.lnum == lnum then
      count = count + 1
    end
  end
  return count
end

-- Mirrors what Neovim's virtual_lines handler puts under the cursor line: the
-- diagnostics starting on it, or, when there are none, every diagnostic whose
-- range covers it. Matching on the start line alone would leave the inline text
-- of a multi-line diagnostic on screen next to its own virtual lines.
local function shown_as_virtual_lines(diagnostic)
  local bufnr = diagnostic.bufnr or vim.api.nvim_get_current_buf()
  local lnum = cursor_lnum(bufnr)
  if not lnum then
    return false
  end
  if starting_on(bufnr, lnum, VIRTUAL_LINES_SEVERITY) > 0 then
    return diagnostic.lnum == lnum
  end
  return diagnostic.end_lnum ~= nil and lnum >= diagnostic.lnum and lnum <= diagnostic.end_lnum
end

-- Room between the end of the code on this line and the right edge of the
-- window. Neovim lays the inline text out as `spacing` blanks, one prefix per
-- diagnostic on the line, then a space and the message of the last one.
local function room_for_virtual_text(diagnostic)
  local bufnr = diagnostic.bufnr or vim.api.nvim_get_current_buf()
  local win = vim.fn.bufwinid(bufnr)
  if win == -1 then
    return 0
  end

  local info = vim.fn.getwininfo(win)[1]
  local gutter = info and info.textoff or 0
  local line = vim.api.nvim_buf_get_lines(bufnr, diagnostic.lnum, diagnostic.lnum + 1, false)[1] or ""
  local on_line = starting_on(bufnr, diagnostic.lnum, VIRTUAL_TEXT_SEVERITY)
  local decoration = VIRTUAL_TEXT_SPACING
    + math.max(1, on_line) * vim.fn.strdisplaywidth(VIRTUAL_TEXT_PREFIX)
    + 1

  return vim.api.nvim_win_get_width(win) - gutter - vim.fn.strdisplaywidth(line) - decoration
end

vim.diagnostic.config({
  virtual_text = {
    severity = VIRTUAL_TEXT_SEVERITY,
    source = "if_many",
    prefix = VIRTUAL_TEXT_PREFIX,
    spacing = VIRTUAL_TEXT_SPACING,
    format = function(diagnostic)
      if shown_as_virtual_lines(diagnostic) then
        return nil
      end
      local room = room_for_virtual_text(diagnostic)
      if room < MIN_VIRTUAL_TEXT_WIDTH then
        return nil
      end
      return truncate(table.concat(useful_lines(diagnostic.message), " "), room)
    end,
  },
  virtual_lines = {
    current_line = true,
    severity = VIRTUAL_LINES_SEVERITY,
    -- newlines are kept: each one becomes its own virtual line, which is what
    -- keeps a long message on screen instead of running off the right edge
    format = function(diagnostic)
      return table.concat(useful_lines(diagnostic.message), "\n")
    end,
  },
  float = {
    border = "rounded",
    source = true,
    header = "",
    max_width = 100,
    wrap = true,
  },
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})
