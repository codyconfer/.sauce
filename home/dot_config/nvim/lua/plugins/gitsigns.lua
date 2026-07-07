return {
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            current_line_blame = false,
            on_attach = function(bufnr)
                local gs = require("gitsigns")
                local function map(mode, lhs, rhs, desc)
                    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
                end
                map("n", "]c", function() gs.nav_hunk("next") end, "Git: next hunk")
                map("n", "[c", function() gs.nav_hunk("prev") end, "Git: prev hunk")
                map("n", "<leader>hp", gs.preview_hunk, "Git: preview hunk")
                map("n", "<leader>hs", gs.stage_hunk, "Git: stage hunk")
                map("n", "<leader>hr", gs.reset_hunk, "Git: reset hunk")
                map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Git: blame line")
                map("n", "<leader>tb", gs.toggle_current_line_blame, "Git: toggle line blame")
            end,
        },
    },
    {
        "sindrets/diffview.nvim",
        cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
        dependencies = { "nvim-lua/plenary.nvim" },
        opts = {},
    },
}
