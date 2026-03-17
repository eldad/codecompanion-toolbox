local M = {}

--- Build a shell command from a base string and a list of optional parts.
--- Only non-empty parts are included; parts are joined with a single space.
---
---@param base string The fixed beginning of the command (e.g. "git commit").
---@param parts string[] Optional extra tokens to append (empty strings are skipped).
---@return string
function M.build_cmd(base, parts)
  local tokens = { base }
  for i = 1, #parts do
    local p = vim.trim(parts[i] or "")
    if p ~= "" then
      table.insert(tokens, p)
    end
  end
  return table.concat(tokens, " ")
end

return M
