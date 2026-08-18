vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = false
vim.opt.wrap = false
vim.opt.breakindent = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Diagnostics
--
-- Long messages used to run past the right edge of the window. Inline virtual
-- text is now collapsed to a single line and cut to the room actually left on
-- that screen line, while the full message is rendered as wrapped virtual lines
-- under the cursor line.

local ELLIPSIS = "…"

local function collapse(message)
  local text = message:gsub("%s*\r?\n%s*", " "):gsub("%s%s+", " ")
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
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

-- Below this many columns of free space the inline message is dropped entirely:
-- the sign column still flags the line, and moving onto it shows the full text.
local MIN_VIRTUAL_TEXT_WIDTH = 12

local VIRTUAL_TEXT_PREFIX = "●"
local VIRTUAL_TEXT_SPACING = 2
local VIRTUAL_TEXT_SEVERITY = { min = vim.diagnostic.severity.WARN }

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
  local on_line = vim.diagnostic.get(bufnr, { lnum = diagnostic.lnum, severity = VIRTUAL_TEXT_SEVERITY })
  local decoration = VIRTUAL_TEXT_SPACING
    + math.max(1, #on_line) * vim.fn.strdisplaywidth(VIRTUAL_TEXT_PREFIX)
    + 1

  return vim.api.nvim_win_get_width(win) - gutter - vim.fn.strdisplaywidth(line) - decoration
end

local function cursor_lnum(bufnr)
  local win = vim.fn.bufwinid(bufnr or vim.api.nvim_get_current_buf())
  if win == -1 then
    return nil
  end
  return vim.api.nvim_win_get_cursor(win)[1] - 1
end

vim.diagnostic.config({
  virtual_text = {
    severity = VIRTUAL_TEXT_SEVERITY,
    source = "if_many",
    prefix = VIRTUAL_TEXT_PREFIX,
    spacing = VIRTUAL_TEXT_SPACING,
    format = function(diagnostic)
      -- the cursor line shows the untruncated message as virtual lines instead
      if diagnostic.lnum == cursor_lnum(diagnostic.bufnr) then
        return nil
      end
      local room = room_for_virtual_text(diagnostic)
      if room < MIN_VIRTUAL_TEXT_WIDTH then
        return nil
      end
      return truncate(collapse(diagnostic.message), room)
    end,
  },
  virtual_lines = {
    current_line = true,
    format = function(diagnostic)
      return collapse(diagnostic.message)
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
