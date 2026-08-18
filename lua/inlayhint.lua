-- Inlay hints, scoped to the line under the cursor.
--
-- Shown for a whole buffer they are mostly noise, and a method chain is the
-- worst case: every line of it gets the same type repeated after it. Neovim can
-- only switch its own renderer on per buffer, so that one stays off and the
-- hints for the cursor line are requested and drawn here, in normal and visual
-- mode only.

local M = {}

local ns = vim.api.nvim_create_namespace("CursorInlayHints")
local METHOD = "textDocument/inlayHint"

-- Long enough that holding `j` does not fire a request per line, short enough
-- that the hints feel attached to the cursor.
local DEBOUNCE_MS = 80

-- Bumped whenever the cursor lands somewhere new. A scheduled request, and the
-- answer to one already in flight, are dropped once the token no longer
-- matches, so a fast cursor never paints hints belonging to a line it left.
local seq = 0

local function clear(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  end
end

-- A label is either a plain string or a list of parts, each carrying its own
-- tooltip and jump location. Only the text is drawn.
local function label_text(label)
  if type(label) == "string" then
    return label
  end
  local parts = {}
  for _, part in ipairs(label or {}) do
    parts[#parts + 1] = part.value or ""
  end
  return table.concat(parts)
end

-- Hint columns are character offsets in the client's encoding, extmarks want
-- byte offsets.
local function byte_col(line, character, encoding)
  if encoding == "utf-8" then
    return math.min(character, #line)
  end
  local ok, col = pcall(vim.str_byteindex, line, encoding, character, false)
  return ok and col or math.min(character, #line)
end

-- Draws on top of whatever is already in the namespace: with more than one
-- client answering, each adds its own hints instead of wiping the others'.
local function render(bufnr, lnum, hints, encoding)
  local line = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1]
  if not line then
    return
  end

  for _, hint in ipairs(hints) do
    local position = hint.position
    if position and position.line == lnum then
      local text = label_text(hint.label)
      if text ~= "" then
        if hint.paddingLeft then
          text = " " .. text
        end
        if hint.paddingRight then
          text = text .. " "
        end
        vim.api.nvim_buf_set_extmark(bufnr, ns, lnum, byte_col(line, position.character, encoding), {
          virt_text = { { text, "LspInlayHint" } },
          virt_text_pos = "inline",
          hl_mode = "combine",
        })
      end
    end
  end
end

-- The cursor line alone cannot be asked for: a hint that belongs to a multi-line
-- expression is only reported when the whole expression fits inside the
-- requested range, so asking for one line drops every hint on a wrapped method
-- chain. The window is asked for instead, padded so an expression reaching past
-- the edge still counts, and render() keeps only what sits on the cursor line.
local CONTEXT_LINES = 50

local function request(bufnr, lnum, token)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = METHOD })
  if #clients == 0 then
    return
  end

  local count = vim.api.nvim_buf_line_count(bufnr)
  local first = math.max(0, math.min(lnum, vim.fn.line("w0") - 1) - CONTEXT_LINES)
  local last = math.min(count, math.max(lnum + 1, vim.fn.line("w$")) + CONTEXT_LINES)

  -- Whole lines, so the range needs no character offsets and is the same for
  -- every client regardless of its encoding.
  local range
  if last < count then
    range = { start = { line = first, character = 0 }, ["end"] = { line = last, character = 0 } }
  else
    local tail = vim.api.nvim_buf_get_lines(bufnr, count - 1, count, false)[1] or ""
    range = { start = { line = first, character = 0 }, ["end"] = { line = count - 1, character = #tail } }
  end

  local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr), range = range }
  local tick = vim.b[bufnr].changedtick

  for _, client in ipairs(clients) do
    client:request(METHOD, params, function(err, result)
      if err or not result or token ~= seq then
        return
      end
      if not vim.api.nvim_buf_is_valid(bufnr) or vim.b[bufnr].changedtick ~= tick then
        return
      end
      render(bufnr, lnum, result, client.offset_encoding)
    end, bufnr)
  end
end

function M.enabled(bufnr)
  return vim.b[bufnr or 0].cursor_inlay_hints ~= false
end

-- `moved` marks the cheap path taken on every cursor step: nothing to do while
-- the cursor stays on the line already drawn.
function M.update(bufnr, moved)
  if not vim.api.nvim_buf_is_valid(bufnr) or not M.enabled(bufnr) then
    return
  end
  if vim.api.nvim_get_current_buf() ~= bufnr or vim.api.nvim_get_mode().mode:find("i") then
    return
  end

  local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
  if moved and vim.b[bufnr].cursor_inlay_lnum == lnum then
    return
  end
  vim.b[bufnr].cursor_inlay_lnum = lnum

  seq = seq + 1
  local token = seq
  clear(bufnr)
  vim.defer_fn(function()
    -- the window range is read from the current window, so bail if the cursor
    -- has left the buffer in the meantime
    if token == seq and vim.api.nvim_get_current_buf() == bufnr then
      request(bufnr, lnum, token)
    end
  end, DEBOUNCE_MS)
end

function M.toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local on = not M.enabled(bufnr)
  vim.b[bufnr].cursor_inlay_hints = on
  if on then
    vim.b[bufnr].cursor_inlay_lnum = nil
    M.update(bufnr, false)
  else
    seq = seq + 1
    clear(bufnr)
  end
  return on
end

function M.setup()
  local group = vim.api.nvim_create_augroup("CursorInlayHints", { clear = true })

  vim.api.nvim_create_autocmd({ "CursorMoved", "InsertLeave", "LspAttach", "BufEnter" }, {
    group = group,
    callback = function(args)
      M.update(args.buf, args.event == "CursorMoved")
    end,
    desc = "Show inlay hints for the line under the cursor",
  })

  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    callback = function(args)
      -- drops whatever is in flight, so a late answer cannot draw into insert mode
      seq = seq + 1
      clear(args.buf)
      vim.b[args.buf].cursor_inlay_lnum = nil
    end,
    desc = "Hide inlay hints while typing",
  })
end

return M
