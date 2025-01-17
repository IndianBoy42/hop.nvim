local defaults = require("hop.defaults")
local hint = require("hop.hint")
local constants = require("hop.constants")
local window = require("hop.window")

local M = {}

-- Allows to override global options with user local overrides.
local function get_command_opts(local_opts)
	-- In case, local opts are defined, chain opts lookup: [user_local] -> [user_global] -> [default]
	return local_opts and setmetatable(local_opts, { __index = M.opts }) or M.opts
end
M.get_command_opts = get_command_opts

-- Display error messages.
local function eprintln(msg, teasing)
	if teasing then
		vim.api.nvim_echo({ { msg, "Error" } }, true, {})
	end
end

-- A hack to prevent #57 by deleting twice the namespace (it’s super weird).
local function clear_namespace(buf_handle, hl_ns)
	vim.api.nvim_buf_clear_namespace(buf_handle, hl_ns, 0, -1)
	vim.api.nvim_buf_clear_namespace(buf_handle, hl_ns, 0, -1)
end

-- Grey everything out to prepare the Hop session.
--
-- - hl_ns is the highlight namespace.
-- - top_line is the top line in the buffer to start highlighting at
-- - bottom_line is the bottom line in the buffer to stop highlighting at
local function grey_things_out(buf_handle, hl_ns, top_line, bottom_line, direction_mode)
	clear_namespace(buf_handle, hl_ns)

	if direction_mode ~= nil then
		if direction_mode.direction == constants.HintDirection.AFTER_CURSOR then
			vim.api.nvim_buf_add_highlight(buf_handle, hl_ns, "HopUnmatched", top_line, direction_mode.cursor_col, -1)
			for line_i = top_line + 1, bottom_line do
				vim.api.nvim_buf_add_highlight(buf_handle, hl_ns, "HopUnmatched", line_i, 0, -1)
			end
		elseif direction_mode.direction == constants.HintDirection.BEFORE_CURSOR then
			for line_i = top_line, bottom_line - 1 do
				vim.api.nvim_buf_add_highlight(buf_handle, hl_ns, "HopUnmatched", line_i, 0, -1)
			end
			vim.api.nvim_buf_add_highlight(buf_handle, hl_ns, "HopUnmatched", bottom_line, 0, direction_mode.cursor_col)
		end
	else
		for line_i = top_line, bottom_line do
			vim.api.nvim_buf_add_highlight(buf_handle, hl_ns, "HopUnmatched", line_i, 0, -1)
		end
	end
end

-- Hint the whole visible part of the buffer.
--
-- The 'hint_mode' argument is the mode to use to hint the buffer.
local function hint_with(hint_mode, opts)
	local context = window.get_window_context(opts.direction)
	-- create the highlight group and grey everything out; the highlight group will allow us to clean everything at once
	-- when hop quits
	local hl_ns = vim.api.nvim_create_namespace("")
	grey_things_out(0, hl_ns, context.top_line, context.bot_line, context.direction_mode)

	-- hint_counts allows us to display some error diagnostics to the user, if any, or even perform direct jump in the
	-- case of a single match
	local hint_list = hint_mode:get_hint_list(opts)

	local h = nil
	if #hint_list == 0 then
		eprintln(" -> there’s no such thing we can see…", opts.teasing)
		clear_namespace(0, hl_ns)
		return
	elseif opts.jump_on_sole_occurrence and #hint_list == 1 then
		h = hint_list[1]
		clear_namespace(0, hl_ns)
		vim.api.nvim_win_set_cursor(0, { h.line + 1, h.col - 1 })
		return
	end

	-- mutate hint_list to add character targets
	hint.assign_character_targets(context, hint_list, opts)

	-- organize hints by line
	local hints = {}
	for _, hint_item in pairs(hint_list) do
		if hints[hint_item.line] == nil then
			hints[hint_item.line] = { hints = {} }
		end
		local line_hints = hints[hint_item.line].hints
		line_hints[#line_hints + 1] = hint_item
	end

	local hint_state = {
		hints = hints,
		hl_ns = hl_ns,
		top_line = context.top_line,
		bot_line = context.bot_line,
	}

	hint.set_hint_extmarks(hl_ns, hints)
	vim.cmd("redraw")

	while h == nil do
		local ok, key = pcall(vim.fn.getchar)
		if not ok then
			M.quit(0, hl_ns)
			break
		end
		local not_special_key = true
		-- :h getchar(): "If the result of expr is a single character, it returns a
		-- number. Use nr2char() to convert it to a String." Also the result is a
		-- special key if it's a string and its first byte is 128.
		--
		-- Note of caution: Even though the result of `getchar()` might be a single
		-- character, that character might still be multiple bytes.
		if type(key) == "number" then
			key = vim.fn.nr2char(key)
		elseif key:byte() == 128 then
			not_special_key = false
		end

		if not_special_key and opts.keys:find(key, 1, true) then
			-- If this is a key used in hop (via opts.keys), deal with it in hop
			h = M.refine_hints(0, key, opts.teasing, context.direction_mode, hint_state)
			vim.cmd("redraw")
		else
			-- If it's not, quit hop
			M.quit(0, hl_ns)
			-- If the key captured via getchar() is not the quit_key, pass it through
			-- to nvim to be handled normally (including mappings)
			if key ~= vim.api.nvim_replace_termcodes(opts.quit_key, true, false, true) then
				vim.api.nvim_feedkeys(key, "", true)
			end
			break
		end
	end
end
M.hint_with = hint_with -- Expose to allow users to add custom searches

-- Refine hints in the given buffer.
--
-- Refining hints allows to advance the state machine by one step. If a terminal step is reached, this function jumps to
-- the location. Otherwise, it stores the new state machine.
function M.refine_hints(buf_handle, key, teasing, direction_mode, hint_state)
	local h, hints, update_count = hint.reduce_hints_lines(hint_state.hints, key)

	if h == nil then
		if update_count == 0 then
			eprintln("no remaining sequence starts with " .. key, teasing)
			return
		end

		hint_state.hints = hints

		grey_things_out(buf_handle, hint_state.hl_ns, hint_state.top_line, hint_state.bot_line, direction_mode)
		hint.set_hint_extmarks(hint_state.hl_ns, hints)
		vim.cmd("redraw")
	else
		M.quit(buf_handle, hint_state.hl_ns)

		-- prior to jump, register the current position into the jump list
		vim.cmd("normal! m'")

		-- JUMP!
		vim.api.nvim_win_set_cursor(0, { h.line + 1, h.col - 1 })
		return h
	end
end

-- Quit Hop and delete its resources.
--
-- This works only if the current buffer is Hop one.
function M.quit(buf_handle, hl_ns)
	clear_namespace(buf_handle, hl_ns)
end

function M.hint_words(opts)
	hint_with(hint.by_word_start, get_command_opts(opts))
end

-- Treesitter hintings
function M.hint_locals(filter, opts)
	hint_with(hint.treesitter_locals(filter), get_command_opts(opts))
end
function M.hint_definitions(opts)
	M.hint_locals(function(loc)
		return loc.definition
	end, opts)
end
function M.hint_scopes(opts)
	M.hint_locals(function(loc)
		return loc.scope
	end, opts)
end
local ts_utils = require("nvim-treesitter.ts_utils")
function M.hint_references(opts, pattern)
	if pattern == nil then
		M.hint_locals(function(loc)
			return loc.reference
		end, opts)
	else
		if pattern == "<cword>" or pattern == "<cWORD>" then
			pattern = vim.fn.expand(pattern)
		end
		M.hint_locals(function(loc)
			return loc.reference and string.match(ts_utils.get_node_text(loc.reference.node)[1], pattern)
				or loc.definition and string.match(ts_utils.get_node_text(loc.definition.node)[1], pattern)
		end, opts)
	end
end
local function ends_with(str, ending)
	return ending == "" or str:sub(-#ending) == ending
end
function M.hint_textobjects(query, opts)
	if type(query) == "string" then
		-- if ends_with(query, "outer") then
		-- end
		query = { query = query }
	end
	hint_with(
		hint.treesitter_queries(
			query and query.query,
			query and query.inners,
			query and query.outers,
			query and query.queryfile
		),
		get_command_opts(opts)
	)
end

function M.hint_patterns(opts, pattern)
	opts = get_command_opts(opts)

	-- The pattern to search is either retrieved from the (optional) argument
	-- or directly from user input.
	local pat
	if pattern then
		pat = pattern
	else
		vim.fn.inputsave()
		local ok
		ok, pat = pcall(vim.fn.input, "Search: ")
		vim.fn.inputrestore()
		if not ok then
			return
		end
	end

	if #pat == 0 then
		eprintln("-> empty pattern", opts.teasing)
		return
	end

	hint_with(hint.by_case_searching(pat, false, opts), opts)
end

function M.hint_char1(opts)
	opts = get_command_opts(opts)
	local ok, c = pcall(vim.fn.getchar)
	if not ok then
		return
	end
	hint_with(hint.by_case_searching(vim.fn.nr2char(c), true, opts), opts)
end

function M.hint_char1_line(opts)
	opts = get_command_opts(opts)
	local ok, c = pcall(vim.fn.getchar)
	if not ok then
		return
	end
	hint_with(hint.by_case_searching_line(vim.fn.nr2char(c), true, opts), opts)
end

function M.hint_char2(opts)
	opts = get_command_opts(opts)
	local ok, a = pcall(vim.fn.getchar)
	if not ok then
		return
	end
	local ok2, b = pcall(vim.fn.getchar)
	if not ok2 then
		return
	end
	local pat = vim.fn.nr2char(a) .. vim.fn.nr2char(b)
	hint_with(hint.by_case_searching(pat, true, opts), opts)
end

function M.hint_cWORD(opts)
	opts = get_command_opts(opts)
	local pat = vim.fn.expand("<cWORD>")
	hint_with(hint.by_case_searching(pat, true, opts), opts)
end
function M.hint_cword(opts)
	opts = get_command_opts(opts)
	local pat = vim.fn.expand("<cword>")
	hint_with(hint.by_case_searching(pat, true, opts), opts)
end

function M.hint_lines(opts)
	hint_with(hint.by_line_start, get_command_opts(opts))
end

function M.hint_lines_vertical(opts)
	hint_with(hint.by_line_vertical, get_command_opts(opts))
end

function M.hint_lines_skip_whitespace(opts)
	hint_with(hint.by_line_start_skip_whitespace(), get_command_opts(opts))
end

-- Setup user settings.
M.opts = defaults
function M.setup(opts)
	-- Look up keys in user-defined table with fallback to defaults.
	M.opts = setmetatable(opts or {}, { __index = defaults })

	-- Insert the highlights and register the autocommand if asked to.
	local highlight = require("hop.highlight")
	highlight.insert_highlights()

	if M.opts.create_hl_autocmd then
		highlight.create_autocmd()
	end
end

return M
