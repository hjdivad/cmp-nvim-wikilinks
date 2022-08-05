local cmp = require('cmp')
if cmp == nil then
  error('cmp-nvim-wikilinks requires cmp')
end


--TODO: log
-- <https://github.com/hjdivad/dotfiles/blob/c44b70a46bc82f09301a633b3b885e839d46016a/home/.config/nvim.symlink/lua/hjdivad/utils.lua#L4-L19>

-- TODO: rename to cmp-nvim-wikilinks-markdown
local CmpWikilinks = {}

CmpWikilinks.new = function()
  return setmetatable({}, { __index = CmpWikilinks })
end

function CmpWikilinks:setup()
  -- require('cmp_vimpath').setup { ... }
  -- TODO: impl
end

function CmpWikilinks:is_available()
  -- TODO: impl; do this only when explicitly enabled
  --  * userland callback
  --  * buffer-local flag
  --  * always
  -- return vim.b.cmp_vimpath
  return true
end

function CmpWikilinks:get_debug_name()
  -- TODO: cmp-nvim-wikilinks
  return 'cmp-vimpath'
end

function CmpWikilinks:get_trigger_character()
  return { '/' }
end

-- TODO: can we close a dangling wikilink?
-- e.g. complete [[fo -> [[foo]]
--
-- see <https://github.com/hrsh7th/nvim-cmp/blob/c4dcb1244a8942b8d2bd3c0a441481e12f91cdf1/lua/cmp/source.lua#L297-L301>
function CmpWikilinks:complete(params, callback)
  -- local offset = params.offset
  -- local context = params.context
  -- local completion_context = params.completion_context
  local line = vim.api.nvim_get_current_line()
  local column = params.context.cursor.col

  -- TODO: complete everything up to the last / and then *
  local completion_pattern = CmpWikilinks._get_completion_pattern(line, column)
  if completion_pattern then
    local items = CmpWikilinks._find_completion_items(completion_pattern)

    callback {
      items = items,
      -- set isIncomplete to true to recompute completions on each keystroke
      -- otherwise they'll be recomputed when the last char is in trigger_character (or if done manually)
      -- isIncomplete = true
    }
  end
end

function CmpWikilinks:resolve(completion_item, callback)
  -- TODO: create preview text by reading the file
  --
  -- completion_item.documentation = {
  --   kind = cmp.lsp.MarkupKind.Markdown,
  --   value = [[
  --   # Interesting

  --   * but
  --   * does
  --   * it
  --   * work

  --   **these** are the questions
  --   ]]
  -- }
  callback(completion_item)
end

-- function CmpVimPath:execute(completion_item, callback)
--   callback()
-- end

local WikiLinkPattern = '%[%[([^][]-)%]%]'
local WikiLinksOpenToNextPattern = '%[%[([^[]-)%['
local WikiLinksOpenToEOLPattern = '%[%[([^][]-)$'
CmpWikilinks._get_completion_pattern = function(line, column)
  local sidx
  local idx = 1

  -- search the line to see if the cursor is within a [[]] link
  while true do
    sidx, idx = line:find(WikiLinkPattern, idx)

    if sidx == nil then
      break
    end

    if column >= sidx + 2 and column <= idx - 1 then
      return line:sub(sidx + 2, column - 1)
    end
  end

  -- search the line to see if the cursor is after a [[ at the end of the line
  sidx, idx = line:find(WikiLinksOpenToEOLPattern)
  if sidx and column >= sidx + 2 then
    return line:sub(sidx + 2, column - 1)
  end

  -- search the line to see if the cursor is after a [[ before the next [[]] link
  while true do
    sidx, idx = line:find(WikiLinksOpenToNextPattern, idx)

    if sidx == nil then
      break
    end

    if column >= sidx + 2 and column <= idx - 1 then
      return line:sub(sidx + 2, column - 1)
    end
  end

  return nil
end

CmpWikilinks._find_completion_items = function(pattern, ...)
  local opts = ({ ... })[1] or {}
  local globpath = opts.globpath or vim.fn.globpath
  local paths = opts.paths or vim.opt.path:get()

  local matches = globpath(vim.o.path, pattern .. '*', false, true)
  local items = vim.tbl_map(function(path)
    -- see <https://github.com/hrsh7th/nvim-cmp/blob/c4dcb1244a8942b8d2bd3c0a441481e12f91cdf1/lua/cmp/types/lsp.lua#L173-L191>
    -- TODO: can we control the order?
    return {
      label = CmpWikilinks._shorten_item(path, paths, matches),
      -- insertText = path,
    }
  end, matches)

  return items
end

local function filter_map(fn, items)
  return vim.tbl_filter(function(x)
    return x
  end, vim.tbl_map(fn, items))
end

CmpWikilinks._shorten_item = function(item, paths, items, ...)
  local opts = ({ ... })[1] or {}
  local cwd = opts.cwd or vim.fn.getcwd()
  local unambiguous_choices = CmpWikilinks._unambiguous_abbreviations(item, paths, items)

  if #unambiguous_choices > 0 then
    return CmpWikilinks._strip_suffix(CmpWikilinks._shortest_path(unambiguous_choices))
  else
    return CmpWikilinks._strip_suffix(item:sub(#cwd + 2))
  end
end

CmpWikilinks._unambiguous_abbreviations = function(item, paths, items)
  return filter_map(function(path)
    if not vim.startswith(item, path) then
      -- doesn't match this path
      return nil
    end

    local potentional_match = item:sub(#path + 2)
    if #potentional_match == 0 then
      -- don't shorten entries in paths to ''
      return nil
    end

    local conflicts = filter_map(function(other_path)
      if path == other_path then
        return nil
      end

      local potential_conflict = other_path .. '/' .. potentional_match

      local c = vim.tbl_contains(items, potential_conflict)
      return c
    end, paths)

    if #conflicts > 0 then
      return nil
    else
      return potentional_match
    end

    return #conflicts == 0
  end, paths)
end

local function count_matches(s, p)
  local c = 0
  for _ in s:gmatch(p) do
    c = c + 1
  end
  return c
end

CmpWikilinks._shortest_path = function(items)
  table.sort(items, function(a, b)

    local a_pathseps = count_matches(a, '/')
    local b_pathseps = count_matches(b, '/')

    if a_pathseps < b_pathseps then
      return true
    elseif b_pathseps < a_pathseps then
      return false
    end

    return a < b
  end)

  return items[1]
end

CmpWikilinks._strip_suffix = function(item)
  for _, suffix in ipairs(vim.opt.suffixesadd:get()) do
    if vim.endswith(item, suffix) then
      return item:sub(1, #item - #suffix)
    end
  end

  return item
end

local singleton = CmpWikilinks.new()

cmp.register_source('wikilinks', singleton)

return singleton
