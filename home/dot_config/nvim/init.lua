vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("sauce.options")
require("sauce.keymaps")

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none", "--branch=stable",
        "https://github.com/folke/lazy.nvim.git", lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins", {
    install = { colorscheme = { "default" } },
    checker = { enabled = false },
    change_detection = { notify = false },
})

pcall(vim.cmd.colorscheme, "default")
