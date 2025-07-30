local Util = require("flash.util")

---@class Flash.Pattern
---@field pattern string
---@field search string
---@field skip string
---@field trigger string
---@field mode Flash.Pattern.Mode
---@field case_options? {ignorecase: boolean, smartcase: boolean}
---@operator call:string Returns the input pattern
local M = {}
M.__index = M

---@alias Flash.Pattern.Mode "exact" | "fuzzy" | "search" | (fun(input:string):string,string?)

---@param pattern string
---@param mode Flash.Pattern.Mode
---@param trigger string
---@param case_options? {ignorecase: boolean, smartcase: boolean}
function M.new(pattern, mode, trigger, case_options)
  local self = setmetatable({}, M)
  self.mode = mode
  self.trigger = trigger or ""
  self.case_options = case_options
  self:set(pattern or "")
  return self
end

function M:__eq(other)
  return other and other.pattern == self.pattern and other.mode == self.mode
end

function M:clone()
  return M.new(self.pattern, self.mode, self.trigger, self.case_options)
end

function M:empty()
  return self.pattern == ""
end

---@param pattern string
---@return boolean updated
function M:set(pattern)
  if pattern ~= self.pattern then
    self.pattern = pattern
    if pattern == "" then
      self.search = ""
      self.skip = ""
    else
      if self.trigger ~= "" and pattern:sub(-1) == self.trigger then
        pattern = pattern:sub(1, -2)
      end
      self.search, self.skip = M._get(pattern, self.mode, self.case_options)
    end
    return false
  end
  return true
end

---@param char string
function M:extend(char)
  if char == Util.BS then
    return self.pattern:sub(1, -2)
  end
  return self.pattern .. char
end

---@return string the input pattern
function M:__call()
  return self.pattern
end

---@param pattern string
---@param mode Flash.Pattern.Mode
---@param case_options? {ignorecase: boolean, smartcase: boolean}
---@private
function M._get(pattern, mode, case_options)
  local skip ---@type string?
  if type(mode) == "function" then
    pattern, skip = mode(pattern)
  elseif mode == "exact" then
    pattern, skip = M._exact(pattern, case_options)
  elseif mode == "fuzzy" then
    local opts = case_options
        and {
          ignorecase = case_options.ignorecase,
          smartcase = case_options.smartcase,
        }
      or nil
    pattern, skip = M._fuzzy(pattern, opts)
  end
  return pattern, skip or pattern
end

---@param pattern string
---@param case_options? {ignorecase: boolean, smartcase: boolean}
function M._exact(pattern, case_options)
  local escaped = "\\V" .. pattern:gsub("\\", "\\\\")
  if case_options then
    local case_flag = Util.get_case_flag(pattern, case_options)
    return escaped .. case_flag
  end
  return escaped
end

---@param opts? {ignorecase: boolean, smartcase: boolean, whitespace:boolean}
function M._fuzzy(pattern, opts)
  opts = vim.tbl_deep_extend("force", {
    ignorecase = vim.go.ignorecase,
    smartcase = vim.go.smartcase,
    whitespace = false,
  }, opts or {})

  local sep = opts.whitespace and ".\\{-}" or "\\[^\\ ]\\{-}"

  ---@param c string
  local chars = vim.tbl_map(function(c)
    return c == "\\" and "\\\\" or c
  end, vim.fn.split(pattern, "\\zs"))

  -- Determine case sensitivity using smartcase logic if enabled
  local ignore_case
  if opts.smartcase and pattern:match("%u") then
    ignore_case = false -- pattern contains uppercase, use case-sensitive
  else
    ignore_case = opts.ignorecase
  end

  local ret = "\\V" .. table.concat(chars, sep) .. (ignore_case and "\\c" or "\\C")
  return ret, ret .. sep
end

return M
