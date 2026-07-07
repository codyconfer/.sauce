return {
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "master",
        build = ":TSUpdate",
        event = { "BufReadPost", "BufNewFile" },
        main = "nvim-treesitter.configs",
        opts = {
            ensure_installed = require("sauce.toolset").parsers,
            auto_install = true,
            highlight = { enable = true },
            indent = { enable = true },
        },
    },
}
