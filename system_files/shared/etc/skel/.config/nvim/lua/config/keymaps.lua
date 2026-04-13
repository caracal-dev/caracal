-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
-- set leader key to space
vim.g.mapleader = " "

local keymap = vim.keymap -- for conciseness
---------------------
-- General Keymaps -------------------

-- use jk to exit insert mode
keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })

--make navigation a bit more logical
keymap.set("n", "1", "0", { desc = "Jump to beginning of line" })
keymap.set("n", "0", "$", { desc = "jump to end of line" })

--same navigation but for visual mode
keymap.set("v", "1", "0", { desc = "Jump to beginning of line" })
keymap.set("v", "0", "$", { desc = "jump to end of line" })

--make yanking and deleting whole words more logical
keymap.set("n", "yw", "yiw", { desc = "Yanks current word under cursor" })
keymap.set("n", "ye", "yw", { desc = "Yanks from cursor placement to the end of the word" })

--make yanking and deleting whole words more logical
keymap.set("v", "yw", "yiw", { desc = "Yanks current word under cursor" })
keymap.set("v", "ye", "yw", { desc = "Yanks from cursor placement to the end of the word" })

--make yanking and deleting whole words more logical
keymap.set("n", "dw", "diw", { desc = "Deletes current word under cursor" })
keymap.set("n", "de", "dw", { desc = "Deletes from cursor placement to the end of the word" })

--make yanking and deleting whole words more logical
keymap.set("v", "dw", "diw", { desc = "Deletes current word under cursor" })
keymap.set("v", "de", "dw", { desc = "Deletes from cursor placement to the end of the word" })

-- clear search highlights
keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

-- fix control V keymap
--keymap.set("n","<leader>vl","C-v", { desc = "visual in start of line"} )
-- delete single character without copying into register
-- keymap.set("n", "x", '"_x')

-- increment/decrement numbers
keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment number" }) -- increment
keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement number" }) -- decrement

-- window management

keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" }) -- split window vertically
keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" }) -- split window horizontally
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" }) -- make split windows equal width & height
keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" }) -- close current split window

keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" }) -- open new tab
keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" }) -- close current tab
keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" }) --  go to next tab
keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" }) --  go to previous tab
keymap.set("n", "<leader>tf", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" }) --  move current buffer to new tab
keymap.set("n", "[", "}", { desc = "next paragraph down" })
keymap.set("n", "]", "{", { desc = "next paragraph up" })
--terminal mode keymap
keymap.set("t", "jk", "<C-\\><C-N>")

--set focus back to opened file
keymap.set("n", "<leader>fe", "<C-w>l", { noremap = true, silent = true })

keymap.set("n", "<leader>vb", "<C-q>", { desc = "visual block because control v is used by paste" })

--refactor keymaps
keymap.set("x", "<leader>re", ":Refactor extract<CR> ")
keymap.set("x", "<leader>rf", ":Refactor extract_to_file <CR>")

keymap.set("x", "<leader>rv", ":Refactor extract_var <CR>")

keymap.set({ "n", "x" }, "<leader>ri", ":Refactor inline_var<CR>")

keymap.set("n", "<leader>rI", ":Refactor inline_func<CR>")

keymap.set("n", "<leader>rb", ":Refactor extract_block<CR>")
keymap.set("n", "<leader>rbf", ":Refactor extract_block_to_file<CR>")
