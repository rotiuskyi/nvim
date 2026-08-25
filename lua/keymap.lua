local map = vim.keymap.set
local fzf = require("fzf-lua")

map("n", "<Esc>", "<Cmd>nohlsearch<CR>")

-- netrw, no file-tree plugin
map("n", "<leader>e", "<Cmd>Explore<CR>", { desc = "[E]xplore files" })

map("n", "<leader><leader>", fzf.files, { desc = "Find files" })
map("n", "<leader>/", fzf.live_grep, { desc = "Grep the project" })
map("n", "<leader>ff", fzf.files, { desc = "[F]ind [F]iles" })
map("n", "<leader>fg", fzf.live_grep, { desc = "[F]ind by [G]rep" })
map("n", "<leader>fb", fzf.buffers, { desc = "[F]ind [B]uffers" })
map("n", "<leader>fh", fzf.helptags, { desc = "[F]ind [H]elp" })

-- <leader>e belongs to netrw, so the diagnostic float sits on <leader>d
map("n", "<leader>d", vim.diagnostic.open_float, { desc = "Show [D]iagnostic message" })
map("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })
map("n", "[d", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Previous [D]iagnostic" })
map("n", "]d", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next [D]iagnostic" })

map("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
map("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
map("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
map("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

map("n", "<leader>z", function()
  require("zen-mode").toggle()
end, { desc = "[Z]en Mode" })

-- Rust / Cargo
map("n", "<leader>rb", "<cmd>!cargo build<CR>", { desc = "Ca[R]go [B]uild" })
map("n", "<leader>rt", "<cmd>!cargo test<CR>", { desc = "Ca[R]go [T]est" })
map("n", "<leader>rc", "<cmd>!cargo clippy<CR>", { desc = "Ca[R]go [C]lippy" })

local crates = require("crates")
map("n", "<leader>ct", crates.toggle, { silent = true, desc = "[C]rates [T]oggle" })
map("n", "<leader>cr", crates.reload, { silent = true, desc = "[C]rates [R]eload" })
map("n", "<leader>cu", crates.upgrade_crate, { silent = true, desc = "[C]rates [U]pgrade" })
map("n", "<leader>cA", crates.upgrade_all_crates, { silent = true, desc = "[C]rates upgrade [A]ll" })

-- VSCode-style shortcuts
--
-- Every one of these takes a key that already means something in vim. The
-- meanings given up are ones with a good replacement: <C-f> and <C-p> lose
-- page-forward and line-up, which <C-d>/<PageDown> and k already do; <C-a>
-- loses increment, <C-z> loses suspend (:suspend still works). <C-w> is the one
-- worth remembering -- the window prefix moves to <leader>W, so splits are
-- <leader>Wv and <leader>Ws.

-- Deliberately not remapped: <C-w> here has to keep its builtin meaning, or the
-- prefix would resolve to the close-buffer mapping below.
map("n", "<leader>W", "<C-w>", { desc = "[W]indow commands" })

-- Insert mode leaves for normal mode first and lets the normal mapping run, so
-- the picker never opens on top of a half-typed line.
local function everywhere(lhs, rhs, desc)
  map({ "n", "x" }, lhs, rhs, { desc = desc })
  map("i", lhs, "<Esc>" .. lhs, { remap = true, desc = desc })
end

everywhere("<C-p>", fzf.files, "Go to file")

-- Find in file is plain `/`: incremental, every match highlighted, n/N to walk
-- them, <Esc> to clear -- the same loop VSCode's find box runs.
map({ "n", "i" }, "<C-f>", "<Esc>/", { desc = "Find in file" })

-- With something selected, search for it instead of opening an empty prompt.
-- \V and the escaping make the selection match literally, so punctuation in it
-- is not read as a pattern.
map("x", "<C-f>", function()
  local save = vim.fn.getreg("z")
  vim.cmd('noautocmd normal! "zy')
  local selection = vim.fn.getreg("z"):gsub("\n.*", "")
  vim.fn.setreg("z", save)
  if selection == "" then
    return
  end
  vim.fn.setreg("/", "\\V" .. vim.fn.escape(selection, "\\/"))
  vim.fn.histadd("search", vim.fn.getreg("/"))
  vim.cmd("normal! n")
end, { desc = "Find selection in file" })

-- Terminal.app cannot tell <C-S-f> from <C-f>: it sends the same byte for both.
-- The mapping is here for terminals that speak the kitty keyboard protocol
-- (Ghostty, kitty, WezTerm, iTerm2); <leader>/ is the one that works everywhere.
everywhere("<C-S-f>", fzf.live_grep, "Find in project")

map({ "n", "x", "i" }, "<C-s>", "<Cmd>write<CR>", { desc = "Save file" })
map("n", "<C-a>", "ggVG", { desc = "Select all" })
map({ "x", "i" }, "<C-a>", "<Esc>ggVG", { desc = "Select all" })
map("n", "<C-z>", "<Cmd>undo<CR>", { desc = "Undo" })
map("n", "<C-y>", "<Cmd>redo<CR>", { desc = "Redo" })
-- <C-o> runs one normal-mode command and comes straight back to insert, which
-- keeps the undo history in one piece.
map("i", "<C-z>", "<C-o>u", { desc = "Undo" })
map("i", "<C-y>", "<C-o><C-r>", { desc = "Redo" })
map("n", "<C-w>", "<Cmd>bdelete<CR>", { desc = "Close buffer" })

-- Ctrl+/ reaches Neovim as <C-_> on terminals that predate the kitty protocol,
-- so both spellings are bound. gc/gcc are Neovim's own commenting mappings,
-- hence remap.
for _, lhs in ipairs({ "<C-/>", "<C-_>" }) do
  map("n", lhs, "gcc", { remap = true, desc = "Toggle comment" })
  map("x", lhs, "gc", { remap = true, desc = "Toggle comment" })
  map("i", lhs, "<Cmd>normal gcc<CR>", { desc = "Toggle comment" })
end

map("x", "<Tab>", ">gv", { desc = "Indent" })
map("x", "<S-Tab>", "<gv", { desc = "Outdent" })

-- Alt+Up/Down needs "Use Option as Meta key" turned on in Terminal.app.
local function move_line(delta)
  return function()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local target = row + delta
    if target < 1 or target > vim.api.nvim_buf_line_count(0) then
      return
    end
    vim.cmd(("silent move %d"):format(delta < 0 and target - 1 or target))
    vim.cmd("normal! ==")
    vim.api.nvim_win_set_cursor(0, { target, math.min(col, #vim.api.nvim_get_current_line()) })
  end
end

map({ "n", "i" }, "<A-Up>", move_line(-1), { desc = "Move line up" })
map({ "n", "i" }, "<A-Down>", move_line(1), { desc = "Move line down" })
map("x", "<A-Up>", ":<C-u>silent! '<,'>move '<-2<CR>gv=gv", { desc = "Move selection up" })
map("x", "<A-Down>", ":<C-u>silent! '<,'>move '>+1<CR>gv=gv", { desc = "Move selection down" })
