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

---@alias Flash.Pattern.Mode "exact" | "fuzzy" | "regex" | "search" | (fun(input:string):string,string?)
--- Pattern modes:
--- - "exact": Matches the pattern literally (very nomagic mode \\V)
--- - "fuzzy": Matches characters in order with flexible separators
--- - "regex": Treats the pattern as a regular expression with case handling
--- - "search": Default Vim search behavior
--- - function: Custom pattern transformation function

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
    pattern, skip = mode(pattern, case_options)
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
  elseif mode == "regex" then
    pattern, skip = M._regex(pattern, case_options)
  end
  return pattern, skip or pattern
end

---@param pattern string
---@param case_options? {ignorecase: boolean, smartcase: boolean}
function M._exact(pattern, case_options)
  if type(pattern) ~= "string" then
    return "\\V"
  end

  local escaped_pattern = pattern:gsub("\\", "\\\\")
  if
    case_options
    and type(case_options) == "table"
    and type(case_options.ignorecase) == "boolean"
    and type(case_options.smartcase) == "boolean"
  then
    local case_flag = Util.get_case_flag(pattern, case_options)
    return "\\V" .. case_flag .. escaped_pattern
  end
  return "\\V" .. escaped_pattern
end

--- Transforms a pattern for regex mode matching.
--- In regex mode, the pattern is treated as a regular expression with optional case handling.
--- Case flags (\\c or \\C) are prepended to control case sensitivity based on ignorecase/smartcase settings.
---@param pattern string The regex pattern to transform
---@param case_options? {ignorecase: boolean, smartcase: boolean} Optional case sensitivity options
---@return string The transformed regex pattern with case flags if applicable
function M._regex(pattern, case_options)
  if type(pattern) ~= "string" then
    return ""
  end

  if
    case_options
    and type(case_options) == "table"
    and type(case_options.ignorecase) == "boolean"
    and type(case_options.smartcase) == "boolean"
  then
    local case_flag = Util.get_case_flag(pattern, case_options)
    return case_flag .. pattern
  end
  return pattern
end

---@param opts? {ignorecase: boolean, smartcase: boolean, whitespace:boolean}
function M._fuzzy(pattern, opts)
  -- Safely get global vim settings with fallback defaults
  local ok_ic, ignorecase = pcall(function()
    return vim.go.ignorecase
  end)
  local ok_sc, smartcase = pcall(function()
    return vim.go.smartcase
  end)

  opts = vim.tbl_deep_extend("force", {
    ignorecase = ok_ic and ignorecase or false,
    smartcase = ok_sc and smartcase or false,
    whitespace = false,
  }, opts or {})

  local sep = opts.whitespace and ".\\{-}" or "\\[^\\ ]\\{-}"

  ---@param c string
  local chars = vim.tbl_map(function(c)
    return c == "\\" and "\\\\" or c
  end, vim.fn.split(pattern, "\\zs"))

  local case_options = { ignorecase = opts.ignorecase, smartcase = opts.smartcase }
  local case_flag = Util.get_case_flag(pattern, case_options)

  local ret = "\\V" .. case_flag .. table.concat(chars, sep)
  return ret, ret .. sep
end

return M
