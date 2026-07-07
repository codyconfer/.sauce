local map = vim.keymap.set

map("n", "<leader>w", "<cmd>w<cr>", { desc = "Write" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })
map("n", "<esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

map("n", "<leader>gd", "<cmd>DiffviewOpen<cr>", { desc = "Diffview: open" })
map("n", "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", { desc = "Diffview: file history" })
map("n", "<leader>gc", "<cmd>DiffviewClose<cr>", { desc = "Diffview: close" })

map("n", "<leader>ut", function()
    vim.ui.select(require("sauce.theme").keys(), { prompt = "goose theme" }, function(choice)
        if choice then vim.cmd.colorscheme(choice) end
    end)
end, { desc = "UI: pick goose theme" })
