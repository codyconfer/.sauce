local M = {
    servers = { "lua_ls", "bashls", "jsonls", "yamlls", "taplo", "marksman" },
    parsers = {
        "lua", "vim", "vimdoc", "query", "bash",
        "json", "jsonc", "yaml", "toml", "markdown", "markdown_inline",
        "git_config", "git_rebase", "gitcommit", "gitignore", "diff",
    },
}

local function merge(dst, src)
    if type(src) ~= "table" then return end
    local seen = {}
    for _, v in ipairs(dst) do seen[v] = true end
    for _, v in ipairs(src) do
        if not seen[v] then
            seen[v] = true
            dst[#dst + 1] = v
        end
    end
end

local ok, gen = pcall(require, "sauce.generated")
if ok and type(gen) == "table" then
    merge(M.servers, gen.servers)
    merge(M.parsers, gen.parsers)
end

return M
