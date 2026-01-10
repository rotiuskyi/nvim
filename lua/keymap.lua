local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>")
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Go to previous [D]iagnostic message" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Go to next [D]iagnostic message" })
map("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show diagnostic [E]rror messages" })
map("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

map("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
map("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
map("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
map("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

vim.g.mapleader = " "
vim.g.maplocalleader = " "

map("n", "<leader>ff", function()
  require("telescope.builtin").find_files()
end, { desc = "[F]ind [F]iles" })
map("n", "<leader>fg", function()
  require("telescope.builtin").live_grep()
end, { desc = "[F]ind by [G]rep" })
map("n", "<leader>fb", function()
  require("telescope.builtin").buffers()
end, { desc = "[F]ind [B]uffers" })
map("n", "<leader>fh", function()
  require("telescope.builtin").help_tags()
end, { desc = "[F]ind [H]elp" })
