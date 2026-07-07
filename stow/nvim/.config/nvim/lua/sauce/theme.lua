local M = {}

M.palettes = {
    ["default"] = {
        light = false,
        accent = "#6e9fff",
        border = "#44474e",
        muted = "#9c9fa3",
        text = "#ececed",
        selected = "#ff9900",
        success = "#6ccf8e",
        warning = "#fbad37",
        failure = "#ff5286",
        info = "#6e9fff",
        series2 = "#d4a0ff",
        bg = "#1c1e26",
    },
    ["solarized-dark"] = {
        light = false,
        accent = "#268bd2",
        border = "#073642",
        muted = "#586e75",
        text = "#93a1a1",
        selected = "#cb4b16",
        success = "#859900",
        warning = "#b58900",
        failure = "#dc322f",
        info = "#2aa198",
        series2 = "#6c71c4",
        bg = "#002b36",
    },
    ["solarized-light"] = {
        light = true,
        accent = "#268bd2",
        border = "#eee8d5",
        muted = "#93a1a1",
        text = "#657b83",
        selected = "#cb4b16",
        success = "#859900",
        warning = "#b58900",
        failure = "#dc322f",
        info = "#2aa198",
        series2 = "#6c71c4",
        bg = "#fdf6e3",
    },
    ["one-dark-vivid"] = {
        light = false,
        accent = "#61afef",
        border = "#3e4451",
        muted = "#5c6370",
        text = "#abb2bf",
        selected = "#ff9d5c",
        success = "#a5e075",
        warning = "#f0c674",
        failure = "#ff616e",
        info = "#4cd1e0",
        series2 = "#de73ff",
        bg = "#282c34",
    },
    ["monokai"] = {
        light = false,
        accent = "#66d9ef",
        border = "#49483e",
        muted = "#75715e",
        text = "#f8f8f2",
        selected = "#fd971f",
        success = "#a6e22e",
        warning = "#e6db74",
        failure = "#f92672",
        info = "#66d9ef",
        series2 = "#ae81ff",
        bg = "#272822",
    },
    ["munin"] = {
        light = false,
        accent = "#ffd700",
        border = "#8a8a8a",
        muted = "#8a8a8a",
        text = "#d0d0d0",
        selected = "#ffd700",
        success = "#5fd787",
        warning = "#ff8700",
        failure = "#ff5f5f",
        info = "#af87ff",
        series2 = "#af87ff",
        bg = "",
    },
    ["retro-dark"] = {
        light = false,
        accent = "#29a3dc",
        border = "#33322e",
        muted = "#8a887c",
        text = "#f4f1e8",
        selected = "#f26522",
        success = "#4caf50",
        warning = "#f7d417",
        failure = "#e6338c",
        info = "#29a3dc",
        series2 = "#9b6dff",
        bg = "#0a0a0a",
    },
    ["retro-light"] = {
        light = true,
        accent = "#16a89c",
        border = "#d9cfb5",
        muted = "#8a7f66",
        text = "#1c1a17",
        selected = "#e0492e",
        success = "#4a9b3f",
        warning = "#e8a41c",
        failure = "#c0392b",
        info = "#16a89c",
        series2 = "#f28c28",
        bg = "#f4ecd8",
    },
}

function M.keys()
    local out = {}
    for k in pairs(M.palettes) do out[#out + 1] = k end
    table.sort(out)
    return out
end

function M.apply(key)
    local p = M.palettes[key]
    if not p then
        vim.notify("goose theme not found: " .. tostring(key), vim.log.levels.ERROR)
        return
    end

    vim.cmd("highlight clear")
    if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end
    vim.o.termguicolors = true
    vim.o.background = p.light and "light" or "dark"
    vim.g.colors_name = key

    local bg = (p.bg ~= nil and p.bg ~= "") and p.bg or "NONE"
    local function hi(group, spec) vim.api.nvim_set_hl(0, group, spec) end

    -- Editor UI
    hi("Normal", { fg = p.text, bg = bg })
    hi("NormalNC", { fg = p.text, bg = bg })
    hi("NormalFloat", { fg = p.text, bg = bg })
    hi("FloatBorder", { fg = p.border, bg = bg })
    hi("FloatTitle", { fg = p.accent, bg = bg, bold = true })
    hi("WinSeparator", { fg = p.border })
    hi("VertSplit", { fg = p.border })
    hi("Comment", { fg = p.muted, italic = true })
    hi("LineNr", { fg = p.muted })
    hi("CursorLineNr", { fg = p.accent, bold = true })
    hi("CursorLine", { bg = p.border })
    hi("CursorColumn", { bg = p.border })
    hi("ColorColumn", { bg = p.border })
    hi("Visual", { bg = p.border })
    hi("Search", { fg = bg, bg = p.selected })
    hi("IncSearch", { fg = bg, bg = p.warning })
    hi("CurSearch", { fg = bg, bg = p.warning })
    hi("Pmenu", { fg = p.text, bg = p.border })
    hi("PmenuSel", { fg = bg, bg = p.accent, bold = true })
    hi("PmenuSbar", { bg = p.border })
    hi("PmenuThumb", { bg = p.muted })
    hi("StatusLine", { fg = p.text, bg = p.border })
    hi("StatusLineNC", { fg = p.muted, bg = bg })
    hi("TabLine", { fg = p.muted, bg = p.border })
    hi("TabLineSel", { fg = p.accent, bg = bg, bold = true })
    hi("TabLineFill", { bg = bg })
    hi("Title", { fg = p.accent, bold = true })
    hi("Directory", { fg = p.accent })
    hi("MatchParen", { fg = p.selected, bold = true })
    hi("NonText", { fg = p.muted })
    hi("Whitespace", { fg = p.muted })
    hi("SignColumn", { bg = bg })
    hi("EndOfBuffer", { fg = bg })
    hi("WinBar", { fg = p.text, bg = bg })
    hi("WinBarNC", { fg = p.muted, bg = bg })

    -- Legacy syntax groups
    hi("Constant", { fg = p.warning })
    hi("Number", { fg = p.warning })
    hi("Float", { fg = p.warning })
    hi("Boolean", { fg = p.warning })
    hi("String", { fg = p.success })
    hi("Character", { fg = p.success })
    hi("Identifier", { fg = p.text })
    hi("Function", { fg = p.accent })
    hi("Statement", { fg = p.series2 })
    hi("Keyword", { fg = p.series2 })
    hi("Conditional", { fg = p.series2 })
    hi("Repeat", { fg = p.series2 })
    hi("Label", { fg = p.series2 })
    hi("Exception", { fg = p.series2 })
    hi("Operator", { fg = p.text })
    hi("Type", { fg = p.info })
    hi("StorageClass", { fg = p.info })
    hi("Structure", { fg = p.info })
    hi("Typedef", { fg = p.info })
    hi("Special", { fg = p.selected })
    hi("SpecialChar", { fg = p.selected })
    hi("Delimiter", { fg = p.muted })
    hi("PreProc", { fg = p.warning })
    hi("Include", { fg = p.warning })
    hi("Define", { fg = p.warning })
    hi("Macro", { fg = p.warning })
    hi("Todo", { fg = bg, bg = p.warning, bold = true })
    hi("Error", { fg = p.failure })
    hi("Underlined", { fg = p.info, underline = true })

    -- Treesitter
    hi("@variable", { fg = p.text })
    hi("@variable.builtin", { fg = p.selected })
    hi("@variable.parameter", { fg = p.text })
    hi("@variable.member", { fg = p.text })
    hi("@field", { fg = p.text })
    hi("@property", { fg = p.text })
    hi("@function", { fg = p.accent })
    hi("@function.call", { fg = p.accent })
    hi("@function.method", { fg = p.accent })
    hi("@function.builtin", { fg = p.accent })
    hi("@constructor", { fg = p.selected })
    hi("@keyword", { fg = p.series2 })
    hi("@keyword.function", { fg = p.series2 })
    hi("@keyword.return", { fg = p.series2 })
    hi("@keyword.operator", { fg = p.series2 })
    hi("@conditional", { fg = p.series2 })
    hi("@repeat", { fg = p.series2 })
    hi("@string", { fg = p.success })
    hi("@string.escape", { fg = p.selected })
    hi("@character", { fg = p.success })
    hi("@number", { fg = p.warning })
    hi("@boolean", { fg = p.warning })
    hi("@constant", { fg = p.warning })
    hi("@constant.builtin", { fg = p.warning })
    hi("@type", { fg = p.info })
    hi("@type.builtin", { fg = p.info })
    hi("@attribute", { fg = p.warning })
    hi("@comment", { fg = p.muted, italic = true })
    hi("@punctuation", { fg = p.muted })
    hi("@punctuation.bracket", { fg = p.muted })
    hi("@punctuation.delimiter", { fg = p.muted })
    hi("@operator", { fg = p.text })
    hi("@tag", { fg = p.series2 })
    hi("@tag.attribute", { fg = p.accent })
    hi("@tag.delimiter", { fg = p.muted })
    hi("@markup.heading", { fg = p.accent, bold = true })
    hi("@markup.link", { fg = p.info, underline = true })
    hi("@markup.raw", { fg = p.success })

    -- Diagnostics
    hi("DiagnosticError", { fg = p.failure })
    hi("DiagnosticWarn", { fg = p.warning })
    hi("DiagnosticInfo", { fg = p.info })
    hi("DiagnosticHint", { fg = p.muted })
    hi("DiagnosticOk", { fg = p.success })
    hi("DiagnosticUnderlineError", { undercurl = true, sp = p.failure })
    hi("DiagnosticUnderlineWarn", { undercurl = true, sp = p.warning })
    hi("DiagnosticUnderlineInfo", { undercurl = true, sp = p.info })
    hi("DiagnosticUnderlineHint", { undercurl = true, sp = p.muted })

    -- LSP references
    hi("LspReferenceText", { bg = p.border })
    hi("LspReferenceRead", { bg = p.border })
    hi("LspReferenceWrite", { bg = p.border })

    -- Gitsigns
    hi("GitSignsAdd", { fg = p.success })
    hi("GitSignsChange", { fg = p.warning })
    hi("GitSignsDelete", { fg = p.failure })
    hi("GitSignsCurrentLineBlame", { fg = p.muted, italic = true })

    -- Diff / diffview
    hi("DiffAdd", { fg = p.success, bg = bg })
    hi("DiffChange", { fg = p.warning, bg = bg })
    hi("DiffDelete", { fg = p.failure, bg = bg })
    hi("DiffText", { fg = p.warning, bold = true })
    hi("diffAdded", { fg = p.success })
    hi("diffChanged", { fg = p.warning })
    hi("diffRemoved", { fg = p.failure })

    -- nvim-cmp
    hi("CmpItemAbbrMatch", { fg = p.accent, bold = true })
    hi("CmpItemAbbrMatchFuzzy", { fg = p.accent })
    hi("CmpItemKind", { fg = p.info })
    hi("CmpItemMenu", { fg = p.muted })

    -- Messages
    hi("ErrorMsg", { fg = p.failure })
    hi("WarningMsg", { fg = p.warning })
    hi("MoreMsg", { fg = p.success })
    hi("Question", { fg = p.info })
    hi("ModeMsg", { fg = p.text, bold = true })
end

return M
