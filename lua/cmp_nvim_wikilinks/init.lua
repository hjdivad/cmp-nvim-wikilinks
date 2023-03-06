local log = require("cmp_nvim_wikilinks/log")
local cmp = require("cmp")
if cmp == nil then
	error("cmp_nvim_wikilinks requires cmp")
end

---@class CmpWikilinks
---@field has_setup boolean
local CmpWikilinks = {}

local has_setup = false
local glob_suffixes = { "*" }

CmpWikilinks.new = function()
	return setmetatable({}, { __index = CmpWikilinks })
end

---@class CmpWikilinksOptions
---@field log_level? string Initial log level ("fatal", "error", "warn", "info", "debug", "trace")
---@field log_to_file? boolean Whether to write log messages to disk
---@field glob_suffixes? string[] suffixes to use when searching.  Defaults to `{"*"}`.  Set to `{"**/*", "*"}` to search everything in &path

---@param options? CmpWikilinksOptions
function CmpWikilinks.setup(options)
	local opts = vim.tbl_deep_extend("force", { log_level = "info", log_to_file = true }, options or {})

	if opts.glob_suffixes then
		glob_suffixes = opts.glob_suffixes
	end
	log.set_level(opts.log_level)
	log.use_file(opts.log_to_file, true)

	has_setup = true
end

function CmpWikilinks:ensure_setup()
	if not has_setup then
		CmpWikilinks.setup({})
	end
end

function CmpWikilinks:is_available()
	-- TODO: impl; do this only when explicitly enabled
	--  * userland callback
	--  * specific filetypes
	--  * always/never
	return true
end

function CmpWikilinks:get_debug_name()
	return "cmp-nvim-wikilinks"
end

function CmpWikilinks:get_trigger_character()
	return { "/" }
end

-- see <https://github.com/hrsh7th/nvim-cmp/blob/c4dcb1244a8942b8d2bd3c0a441481e12f91cdf1/lua/cmp/source.lua#L297-L301>
function CmpWikilinks:complete(params, callback)
	log.trace("complete")
	-- local offset = params.offset
	-- local context = params.context
	-- local completion_context = params.completion_context
	local line = vim.api.nvim_get_current_line()
	local column = params.context.cursor.col

	-- TODO: complete everything up to the last / and then *
	local completion_pattern = CmpWikilinks._get_completion_pattern(line, column)
	if completion_pattern then
		local items = CmpWikilinks._find_completion_items(completion_pattern, { glob_suffixes = glob_suffixes })

		callback({
			items = items,
			-- set isIncomplete to true to recompute completions on each keystroke
			-- otherwise they'll be recomputed when the last char is in trigger_character (or if done manually)
			-- isIncomplete = true
		})
	end
end

---@class CmpWikiLinks.resolve.Options
---@field io iolib The `IO` lib to use. Defaults to the global `io`.

---Resolve the completion item. This tries to read `completion_item.path` and
---add a markdown preview to `completion_item.documentation`
---
---@param completion_item CmpWikiLinks.CompletionItem
---@param options? CmpWikiLinks.resolve.Options
---@param callback any
function CmpWikilinks:resolve(completion_item, callback, options)
	CmpWikilinks._append_preview(completion_item, options)
	callback(completion_item)
end

function CmpWikilinks.set_log_level(level)
	log.set_level(level)
end

function CmpWikilinks.show_logs()
	vim.cmd("tabnew " .. log.outfile)
end

---@param completion_item CmpWikiLinks.CompletionItem
---@param options? CmpWikiLinks.resolve.Options
function CmpWikilinks._append_preview(completion_item, options)
	local path = completion_item.path
	if not path then
		-- unexpected completion item
		return
	end

	local opts = options or {}
	local io = opts.io or io

	local file = io.open(path)
	if not file then
		-- this should be rare (we already found the file via globpath), but
		-- perhaps it was removed async or disk failure &c.
		return
	end

	--TODO: in case of large files, better to read a fixed amount and then delete
	--from the end to the last section start or something similar
	local content = file:read("a")
	completion_item.documentation = {
		kind = "markdown",
		value = content,
	}

	file:close()
end

-- function CmpVimPath:execute(completion_item, callback)
--   callback()
-- end

local WikiLinkPattern = "%[%[([^][]-)%]%]"
local WikiLinksOpenToNextPattern = "%[%[([^[]-)%["
local WikiLinksOpenToEOLPattern = "%[%[([^][]-)$"
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

---@class CmpWikiLinks.CompletionItem Includes necessary fields from `lsp.CompletionItem` with some extensions for internal use.
---
---@field label string The label to show the user as well as the text to complete.
---@field path string The absolute path to the file.
---@field documentation lsp.MarkupContent|nil Preview documentation found for the item.
---
---@see lsp.CompletionItem

---@class CmpWikilinks._find_completion_items.Options
---@field globpath fun(path: string, pat: string, nosuf: boolean, list: boolean): string[] optional function to use for searching `paths`. Defaults to `vim.fn.globpath`
---@field glob_suffixes? string[] Suffixes to use when searching for `pattern` in `paths`
---@field paths string[] The paths to search. Defaults to `vim.opt.path.get()`

---Return a list of completion items for a pattern. The pattern is searched
---across all entries in `&path`.
---
---Items are returned with a `label` that is the shortest unambiguous relative
---path to an entry found in `&path`.
---
---
---@param pattern string a pattern prefix to use for searching the path. A
---trailing `*` is automatically appended before searching.
---@param options? CmpWikilinks._find_completion_items.Options options
---@return CmpWikiLinks.CompletionItem[]
CmpWikilinks._find_completion_items = function(pattern, options)
	local opts = options or {}
	local globpath = opts.globpath or vim.fn.globpath
	local paths = opts.paths or vim.opt.path:get()
	local glob_suffixes = opts.glob_suffixes or { "*" }

	local matches = {}
	for _, glob_suffix in ipairs(glob_suffixes) do
		local new_matches = globpath(vim.o.path, pattern .. glob_suffix, false, true)
		for _, new_match in ipairs(new_matches) do
			table.insert(matches, new_match)
		end
	end

	local items = vim.tbl_map(function(path)
		-- see <https://github.com/hrsh7th/nvim-cmp/blob/c4dcb1244a8942b8d2bd3c0a441481e12f91cdf1/lua/cmp/types/lsp.lua#L173-L191>
		-- TODO: can we control the order?
		return {
			label = CmpWikilinks._shorten_item(path, paths, matches),
			path = path,
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

			local potential_conflict = other_path .. "/" .. potentional_match

			local c = vim.tbl_contains(items, potential_conflict)
			return c
		end, paths)

		if #conflicts > 0 then
			return nil
		else
			return potentional_match
		end
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
		local a_pathseps = count_matches(a, "/")
		local b_pathseps = count_matches(b, "/")

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

cmp.register_source("wikilinks", singleton)

return singleton
