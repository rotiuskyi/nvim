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

-- Neovim draws a virtual line as the indent up to the diagnostic's column, then
-- a branch of a box character, four dashes and a space, then the message.
local VIRTUAL_LINES_BRANCH = 6

-- Wrapping to fewer columns than this gives a ragged stack of fragments rather
-- than something readable, so below it the message is cut to one line instead.
local MIN_VIRTUAL_LINES_WIDTH = 24

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

-- A word wider than the whole column runs on until it fits.
local function split_wide(word, width)
  local pieces = {}
  while vim.fn.strdisplaywidth(word) > width do
    local piece = vim.fn.strcharpart(word, 0, width)
    while vim.fn.strchars(piece) > 1 and vim.fn.strdisplaywidth(piece) > width do
      piece = vim.fn.strcharpart(piece, 0, vim.fn.strchars(piece) - 1)
    end
    table.insert(pieces, piece)
    word = word:sub(#piece + 1)
  end
  table.insert(pieces, word)
  return pieces
end

local function wrap(text, width)
  if width < 1 or vim.fn.strdisplaywidth(text) <= width then
    return { text }
  end

  local lines, current = {}, ""
  for word in text:gmatch("%S+") do
    for _, piece in ipairs(split_wide(word, width)) do
      local candidate = current == "" and piece or (current .. " " .. piece)
      if vim.fn.strdisplaywidth(candidate) <= width then
        current = candidate
      else
        if current ~= "" then
          table.insert(lines, current)
        end
        current = piece
      end
    end
  end
  if current ~= "" then
    table.insert(lines, current)
  end

  return #lines > 0 and lines or { text }
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

-- Room left for the message inside a virtual line: the window, less the gutter,
-- the indent Neovim adds to reach the diagnostic's column, the branch it draws
-- there, and one column per further diagnostic stacked on the same line.
local function room_for_virtual_lines(diagnostic)
  local bufnr = diagnostic.bufnr or vim.api.nvim_get_current_buf()
  local win = vim.fn.bufwinid(bufnr)
  if win == -1 then
    return math.huge
  end

  local info = vim.fn.getwininfo(win)[1]
  local gutter = info and info.textoff or 0
  local line = vim.api.nvim_buf_get_lines(bufnr, diagnostic.lnum, diagnostic.lnum + 1, false)[1] or ""
  local indent = vim.fn.strdisplaywidth(line:sub(1, diagnostic.col))
  local stacked = math.max(1, starting_on(bufnr, diagnostic.lnum, VIRTUAL_LINES_SEVERITY)) - 1

  -- Not floored: the indent is Neovim's to choose, so asking for more columns
  -- than are left would only put the text back off the right edge. A result of
  -- zero or less means the branch alone already fills the window.
  return vim.api.nvim_win_get_width(win) - gutter - indent - VIRTUAL_LINES_BRANCH - stacked
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
  -- A diagnostic with no room left for its message is dropped by the handler
  -- below, so the inline text has to stand in for it.
  if room_for_virtual_lines(diagnostic) < 1 then
    return false
  end
  if starting_on(bufnr, lnum, VIRTUAL_LINES_SEVERITY) > 0 then
    return diagnostic.lnum == lnum
  end
  return diagnostic.end_lnum ~= nil and lnum >= diagnostic.lnum and lnum <= diagnostic.end_lnum
end

-- Neovim gives every diagnostic on a line its own inline chunk and lays them
-- out one after another on the same screen row, so a second message all but
-- guarantees a run past the right edge. Only the most serious one is kept
-- inline; the others show up as virtual lines once the cursor reaches the line,
-- and in full on <leader>d.
local function keeps_inline_text(diagnostic)
  local bufnr = diagnostic.bufnr or vim.api.nvim_get_current_buf()
  local best
  for _, d in ipairs(vim.diagnostic.get(bufnr, { severity = VIRTUAL_TEXT_SEVERITY })) do
    if
      d.lnum == diagnostic.lnum
      and (
        not best
        or d.severity < best.severity
        or (d.severity == best.severity and d.col < best.col)
        or (d.severity == best.severity and d.col == best.col and d.message < best.message)
      )
    then
      best = d
    end
  end
  -- format() is handed a copy, so the winner is matched on its fields
  return best ~= nil
    and best.severity == diagnostic.severity
    and best.col == diagnostic.col
    and best.message == diagnostic.message
end

-- Room between the end of the code on this line and the right edge of the
-- window. What Neovim draws before the message is `spacing` blanks, the prefix,
-- and one separating space.
local function room_for_virtual_text(diagnostic)
  local bufnr = diagnostic.bufnr or vim.api.nvim_get_current_buf()
  local win = vim.fn.bufwinid(bufnr)
  if win == -1 then
    return 0
  end

  local info = vim.fn.getwininfo(win)[1]
  local gutter = info and info.textoff or 0
  local line = vim.api.nvim_buf_get_lines(bufnr, diagnostic.lnum, diagnostic.lnum + 1, false)[1] or ""
  local decoration = VIRTUAL_TEXT_SPACING + vim.fn.strdisplaywidth(VIRTUAL_TEXT_PREFIX) + 1

  return vim.api.nvim_win_get_width(win) - gutter - vim.fn.strdisplaywidth(line) - decoration
end

vim.diagnostic.config({
  virtual_text = {
    severity = VIRTUAL_TEXT_SEVERITY,
    -- Off on purpose: Neovim prepends the source after format() has run, so its
    -- width cannot be budgeted for and it pushed the message off the edge. The
    -- float on <leader>d still names the source.
    source = false,
    prefix = VIRTUAL_TEXT_PREFIX,
    spacing = VIRTUAL_TEXT_SPACING,
    format = function(diagnostic)
      if shown_as_virtual_lines(diagnostic) or not keeps_inline_text(diagnostic) then
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
    -- Every newline becomes its own virtual line, and Neovim never wraps one:
    -- it sets virt_lines_overflow to "scroll", so a long message is drawn as a
    -- single row running past the right edge. Wrapping it here to the room
    -- actually left turns that overflow into further rows.
    format = function(diagnostic)
      local room = room_for_virtual_lines(diagnostic)

      -- Code indented almost to the right edge leaves the branch no room for a
      -- message. Rather than draw one that runs off screen, drop it here: the
      -- sign column still flags the line, the inline text takes over, and
      -- <leader>d has the whole message.
      if room < 1 then
        return nil
      end

      local lines = useful_lines(diagnostic.message)
      if room < MIN_VIRTUAL_LINES_WIDTH then
        return truncate(table.concat(lines, " "), room)
      end

      local wrapped = {}
      for _, line in ipairs(lines) do
        vim.list_extend(wrapped, wrap(line, room))
      end
      return table.concat(wrapped, "\n")
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
