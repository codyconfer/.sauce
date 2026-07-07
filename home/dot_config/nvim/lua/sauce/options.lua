local o = vim.opt

o.number = true
o.relativenumber = true
o.signcolumn = "yes"
o.termguicolors = true
o.updatetime = 200
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.smartindent = true
o.ignorecase = true
o.smartcase = true
o.undofile = true
o.splitright = true
o.splitbelow = true
o.scrolloff = 6
o.clipboard = "unnamedplus"
o.completeopt = { "menu", "menuone", "noselect" }

vim.diagnostic.config({ virtual_text = true, severity_sort = true })
