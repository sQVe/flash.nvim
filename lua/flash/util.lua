local Hacks = require("flash.hacks")

local M = {}

local CASE_SENSITIVE_FLAG = "\\C"
local CASE_INSENSITIVE_FLAG = "\\c"

function M.t(str)
  return vim.api.nvim_replace_termcodes(str, true, true, true)
end

M.CR = M.t("<cr>")
M.ESC = M.t("<esc>")
M.BS = M.t("<bs>")
M.EXIT = M.t("<C-\\><C-n>")
M.LUA_CALLBACK = "\x80\253g"
M.CMD = "\x80\253h"

function M.exit()
  vim.api.nvim_feedkeys(M.EXIT, "nx", false)
  vim.api.nvim_feedkeys(M.ESC, "n", false)
end

---@param buf number
---@param pos number[] (1,0)-indexed position
---@param offset number[]
---@return number[] (1,0)-indexed position
function M.offset_pos(buf, pos, offset)
  local row = pos[1] + offset[1]
  local ok, lines = pcall(vim.api.nvim_buf_get_lines, buf, row - 1, row, true)
  if not ok or lines == nil then
    -- fallback to old behavior if anything wrong happens
    return { row, math.max(pos[2] + offset[2], 0) }
  end

  local line = lines[1]
  local charidx = vim.fn.charidx(line, pos[2])
  local col = vim.fn.byteidx(line, charidx + offset[2])

  return { row, math.max(col, 0) }
end

function M.get_char()
  Hacks.setcursor()
  vim.cmd("redraw")
  local ok, ret = pcall(vim.fn.getcharstr)
  return ok and ret ~= M.ESC and ret or nil
end

function M.layout_wins()
  local queue = { vim.fn.winlayout() }
  ---@type table<window, window>
  local wins = {}
  while #queue > 0 do
    local node = table.remove(queue)
    if node[1] == "leaf" then
      wins[node[2]] = node[2]
    else
      vim.list_extend(queue, node[2])
    end
  end
  return wins
end

function M.save_layout()
  local current_win = vim.api.nvim_get_current_win()
  local wins = M.layout_wins()
  ---@type table<window, table>
  local state = {}
  for _, win in pairs(wins) do
    state[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
  end
  return function()
    for win, s in pairs(state) do
      if vim.api.nvim_win_is_valid(win) then
        local buf = vim.api.nvim_win_get_buf(win)
        -- never restore terminal buffers to prevent flickering
        if vim.bo[buf].buftype ~= "terminal" then
          pcall(vim.api.nvim_win_call, win, function()
            vim.fn.winrestview(s)
          end)
        end
      end
    end
    vim.api.nvim_set_current_win(current_win)
    state = {}
  end
end

---@param done fun():boolean
---@param on_done fun()
function M.on_done(done, on_done)
  local check = assert(vim.loop.new_check())
  local fn = function()
    if check:is_closing() then
      return
    end
    if done() then
      check:stop()
      check:close()
      on_done()
    end
  end
  check:start(vim.schedule_wrap(fn))
end

---@param mode_config table? Mode configuration containing search.ignorecase and search.smartcase
---@param runtime_overrides table? Runtime overrides containing ignorecase and smartcase
---@return table Resolved case options with ignorecase and smartcase boolean values
function M.resolve_case_options(mode_config, runtime_overrides)
  local resolved = {}

  -- Start with global Vim settings as base, with fallback defaults.
  local ok_ic, ignorecase = pcall(function()
    return vim.go.ignorecase
  end)
  local ok_sc, smartcase = pcall(function()
    return vim.go.smartcase
  end)
  resolved.ignorecase = ok_ic and ignorecase or false
  resolved.smartcase = ok_sc and smartcase or false

  if mode_config and type(mode_config.search) == "table" then
    if type(mode_config.search.ignorecase) == "boolean" then
      resolved.ignorecase = mode_config.search.ignorecase
    end
    if type(mode_config.search.smartcase) == "boolean" then
      resolved.smartcase = mode_config.search.smartcase
    end
  end

  -- Apply runtime overrides if available and valid (highest precedence).
  if runtime_overrides and type(runtime_overrides) == "table" then
    if type(runtime_overrides.ignorecase) == "boolean" then
      resolved.ignorecase = runtime_overrides.ignorecase
    end
    if type(runtime_overrides.smartcase) == "boolean" then
      resolved.smartcase = runtime_overrides.smartcase
    end
  end

  return resolved
end

---@param pattern string The search pattern to analyze
---@param case_options table Resolved case options with ignorecase and smartcase fields
---@return boolean True if case should be ignored, false if case-sensitive matching required
function M.should_ignore_case(pattern, case_options)
  if type(pattern) ~= "string" or not case_options or type(case_options) ~= "table" then
    return false
  end

  if type(case_options.ignorecase) ~= "boolean" or type(case_options.smartcase) ~= "boolean" then
    return false
  end

  -- If ignorecase is explicitly false, always be case-sensitive.
  if not case_options.ignorecase then
    return false
  end

  -- If smartcase is disabled, use ignorecase setting directly.
  if not case_options.smartcase then
    return case_options.ignorecase
  end

  -- If pattern contains uppercase, be case-sensitive.
  local has_upper = string.match(pattern, "%u")

  if has_upper then
    return false
  end

  return true
end

---@param pattern string The search pattern to analyze
---@param case_options table Resolved case options with ignorecase and smartcase fields
---@return string Vim regex case flag (`\c` or `\C`)
function M.get_case_flag(pattern, case_options)
  local ignore_case = M.should_ignore_case(pattern, case_options)

  if ignore_case then
    return CASE_INSENSITIVE_FLAG
  else
    return CASE_SENSITIVE_FLAG
  end
end

---@param opts table? Options table containing ignorecase and smartcase
---@param mode_name string The mode name to get configuration for (e.g., "search", "treesitter_search")
---@return table Resolved case options with ignorecase and smartcase fields
function M.resolve_case_options_for_mode(opts, mode_name)
  local Config = require("flash.config")
  local mode_config = Config.get(mode_name)

  local runtime_overrides = opts and {
    ignorecase = opts.ignorecase,
    smartcase = opts.smartcase,
  } or nil

  return M.resolve_case_options(mode_config, runtime_overrides)
end

---@param opts table Options table to modify (MODIFIED IN-PLACE)
---@param case_options table Resolved case options to merge into opts
---@return table The modified opts table with case options merged and ignorecase/smartcase removed
function M.merge_case_options_into_opts(opts, case_options)
  opts = vim.tbl_deep_extend("force", opts, {
    search = {
      case_options = case_options,
    },
  })

  -- Remove runtime overrides after merging.
  opts.ignorecase = nil
  opts.smartcase = nil

  return opts
end

---@param opts table? Options table that may contain ignorecase and smartcase (MODIFIED IN-PLACE if case options present)
---@param mode_name string The mode name to get configuration for (e.g., "search", "treesitter_search")
---@return table? Modified opts with case options resolved, or original opts if no case options provided
function M.resolve_and_merge_case_options(opts, mode_name)
  if not opts or (opts.ignorecase == nil and opts.smartcase == nil) then
    return opts
  end

  local case_options = M.resolve_case_options_for_mode(opts, mode_name)
  return M.merge_case_options_into_opts(opts, case_options)
end

return M
