--- a ux for surrounding character pairs
-- @module surround
local M = {}
local parser = require("surround.parser")
local utils = require("surround.utils")

local OPENING = 1
local CLOSING = 2
local FUNCTION = 3
local LINE = 1
local COLUMN = 2

--- Surround selection.
-- Adds a character surrounding the user's selection in either visual mode or operator pending mode.
-- @param[opt=false] op_mode Boolean value indicating that the function was called from operator pending mode.
-- @param[opt=nil] surrounding The character used to surround text. If ommited, user is asked for input.
-- @param[opt=nil] motion The motion that should be used to select text in operator pending mode. If ommited, user is asked for input.
function M.surround_add(op_mode, surrounding, motion)
	op_mode = op_mode or false

	-- mode_correction is adjusting for differences in how vim
	-- places its markers for visual selection and motions
	local mode, mode_correction
	local ext_mark
	local start_line, start_col, end_line, end_col
	if op_mode then
		-- set visual mode when called as operator pending mode
		mode = "v"
		mode_correction = 0

		motion = motion or utils.get_motion()
		if motion == nil then
			return
		end

		-- use a noop with the g@ operator to set '[ and '] marks
		local cr = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
		local command = ":set operatorfunc=SurroundNoop" .. cr .. "g@" .. motion
		vim.api.nvim_feedkeys(command, "x", true)

		ext_mark = utils.highlight_motion_selection()

		start_line, start_col, end_line, end_col = utils.get_operator_pos()
	else
		mode = vim.api.nvim_get_mode()["mode"]
		mode_correction = 1
		start_line, start_col, end_line, end_col = utils.get_visual_pos()
	end
	local context = vim.api.nvim_call_function("getline", { start_line, end_line })

	local char = surrounding or utils.get_surround_chars()
	-- remove highlighting again that was set when op_mode
	if ext_mark then vim.api.nvim_buf_del_extmark(0, vim.g.surround_namespace, ext_mark) end
	if char == nil then
		return
	end

	if op_mode then
		vim.g.surround_last_cmd = { "surround_add", { true, char, motion } }
	else
		-- When called from visual mode, the command cannot be repeated
		vim.g.surround_last_cmd = nil
	end
	vim.api.nvim_command('silent! call repeat#set("\\<Plug>SurroundRepeat", 1)')

	-- Get the pair to add
	local surround_pairs = vim.g.surround_pairs
	local char_pairs = utils.get_char_pair(char)
	if char_pairs == nil and char ~= "f" then return end

	local space = ""
	if vim.g.surround_space_on_closing_char then
		if table.contains(surround_pairs.nestable, char) and char == char_pairs[CLOSING] then
			space = " "
		end
	else
		if table.contains(surround_pairs.nestable, char) and char == char_pairs[OPENING] then
			space = " "
		end
	end

	-- Add surrounding characters
	if char == "f" then
		-- Handle Functions
		local func_name = utils.user_input("funcname: ")
		if mode == "v" then
			-- Visual Mode
			if #context == 1 then
				-- Handle single line
				local line = context[1]
				line = string.insert(line, end_col, space .. ")")
				line = string.insert(line, start_col, func_name .. "(" .. space)
				context[1] = line
			else
				-- Handle multiple lines
				local first_line = context[1]
				local last_line = context[#context]
				last_line = string.insert(last_line, end_col + mode_correction, space .. ")")
				first_line = string.insert(first_line, start_col, func_name .. "(" .. space)
				context[1] = first_line
				context[#context] = last_line
			end
		end
	else
		if mode == "v" then
			-- Visual Mode
			if #context == 1 then
				-- Handle single line
				local line = context[1]
				line = string.insert(line, end_col + mode_correction, space .. char_pairs[CLOSING])
				line = string.insert(line, start_col, char_pairs[OPENING] .. space)
				context[1] = line
			else
				-- Handle multiple lines
				local first_line = context[1]
				local last_line = context[#context]
				last_line = string.insert(last_line, end_col + mode_correction, space .. char_pairs[CLOSING])
				first_line = string.insert(first_line, start_col, char_pairs[OPENING] .. space)
				context[1] = first_line
				context[#context] = last_line
			end
		elseif mode == "V" then
			-- Visual Line Mode
			if #context == 1 then
				-- Handle single line
				local line = context[1]
				local index = 1
				for i = 1, #line do
					local current_char = line:sub(i, i)
					if current_char ~= " " and current_char ~= "\t" then
						index = i
						break
					end
				end
				line = string.insert(line, #line + 1, space .. char_pairs[CLOSING])
				line = string.insert(line, index, char_pairs[OPENING] .. space)
				context[1] = line
			else
				-- Handle multiple lines
				local first_line = context[1]
				local last_line = context[#context]

				local index = 1
				-- Skip Leading Spaces and Tabs
				for i = 1, #first_line do
					local current_char = first_line:sub(i, i)
					if current_char ~= " " and current_char ~= "\t" then
						index = i
						break
					end
				end

				-- Insert the characters
				last_line = string.insert(last_line, #last_line + 1, space .. char_pairs[CLOSING])
				first_line = string.insert(first_line, index, char_pairs[OPENING] .. space)
				context[1] = first_line
				context[#context] = last_line
			end
		end
	end

	-- Replace buffer with added characters
	vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, true, context)

	-- Get out of visual mode
	local key = vim.api.nvim_replace_termcodes("<esc>", true, false, true)
	vim.api.nvim_feedkeys(key, "v", true)
end

function M.surround_delete(char)
	local cursor_position = vim.api.nvim_win_get_cursor(0)
	local start_line, end_line
	local top_offset = 0
	local context
	local n = 0
	if not char then
		char = utils.get_surround_chars()
		if char == nil then
			return
		end
		if utils.has_value({ "2", "3", "4", "5", "6", "7", "8", "9" }, char) then
			n = tonumber(char) - 1
			char = utils.get_surround_chars()
			if char == nil then
				return
			end
		end
	end

	local char_pairs = utils.get_char_pair(char)
	if char_pairs == nil and char ~= "f" then return end

	-- Get context
	start_line, end_line, top_offset, _ = utils.get_line_numbers_by_offset(vim.g.surround_context_offset)
	context = vim.api.nvim_call_function("getline", { start_line, end_line })
	local cursor_position_relative = cursor_position
	cursor_position_relative[LINE] = cursor_position[LINE] - top_offset
	cursor_position_relative[COLUMN] = cursor_position[COLUMN] + 1 -- vim indexes columns at 0

	-- Find the surrounding pair
	local indexes
	indexes = parser.get_surround_pair(context, cursor_position_relative, char, { "_", "." }, n)

	-- If no surrounding pairs found bail out
	if not indexes then
		print("No surrounding " .. char .. " found")
		return
	end

	-- indexes[3] is the function start index
	local space_opening = (indexes[4] and 1) or 0
	local space_closing = (indexes[5] and 1) or 0

	if char == "f" then
		-- Handle functions
		context[indexes[CLOSING][LINE]] = string.remove(context[indexes[CLOSING][LINE]], indexes[CLOSING][COLUMN])
		context[indexes[OPENING][LINE]] = string.remove(
			context[indexes[OPENING][LINE]],
			indexes[FUNCTION][COLUMN],
			indexes[OPENING][COLUMN] + 1
		)
	else
		-- Remove surrounding character  matches
		context[indexes[CLOSING][LINE]] = string.remove(
			context[indexes[CLOSING][LINE]],
			indexes[CLOSING][COLUMN] - space_closing,
			indexes[CLOSING][COLUMN] + #char_pairs[CLOSING]
		)
		context[indexes[OPENING][LINE]] = string.remove(
			context[indexes[OPENING][LINE]],
			indexes[OPENING][COLUMN],
			indexes[OPENING][COLUMN] + #char_pairs[OPENING] + space_opening
		)
	end

	-- Replace Buffer
	vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, true, context)

	-- Set Last CMD
	vim.api.nvim_command('silent! call repeat#set("\\<Plug>SurroundRepeat", 1)')
	vim.g.surround_last_cmd = { "surround_delete", { char } }

	-- return the adjusted positions of previous surroundings
	if indexes[OPENING][LINE] == indexes[CLOSING][LINE] and char ~= "f" then
		return {
			indexes[OPENING],
			{
				indexes[CLOSING][LINE],
				indexes[CLOSING][COLUMN] - #char_pairs[OPENING] - space_opening - space_closing
			}
		}
	else
		return indexes
	end
end

function M.surround_replace(
	is_toggle,
	start_line,
	end_line,
	top_offset,
	cursor_position_relative,
	context,
	char_1,
	char_2,
	func_name
)
	local n = 0
	if not is_toggle then
		if not char_1 then
			char_1 = utils.get_surround_chars()
			if char_1 == nil then
				return
			end

			if utils.has_value({ "2", "3", "4", "5", "6", "7", "8", "9" }, char_1) then
				n = tonumber(char_1) - 1
				char_1 = utils.get_surround_chars()
				if char_1 == nil then
					return
				end
			end
			char_2 = utils.get_surround_chars()
			if char_2 == nil then
				return
			end
		end
	end

	if not cursor_position_relative or context or start_line or end_line or top_offset then
		top_offset = 0
		local cursor_position = vim.api.nvim_win_get_cursor(0)
		-- Get context
		start_line, end_line, top_offset, _ = utils.get_line_numbers_by_offset(vim.g.surround_context_offset)
		context = vim.api.nvim_call_function("getline", { start_line, end_line })
		cursor_position_relative = cursor_position
		cursor_position_relative[LINE] = cursor_position[LINE] - top_offset
		cursor_position_relative[COLUMN] = cursor_position[COLUMN] + 1 -- vim indexes columns at 0
	end

	-- Replace surrounding pairs
	if char_1 == "f" and char_2 == "f" then
		local indexes = parser.get_surround_pair(context, cursor_position_relative, char_1, { "_" })

		-- Bail out if no surrounding function found.
		if not indexes then
			print("No surrounding function found")
			return
		end

		-- Get new funcname
		if not func_name then
			func_name = utils.user_input("funcname: ")
		end

		-- Delete old function
		context[indexes[FUNCTION][LINE]] = string.remove(
			context[indexes[FUNCTION][LINE]],
			indexes[FUNCTION][COLUMN],
			indexes[OPENING][COLUMN]
		)

		-- Add new function
		context[indexes[FUNCTION][LINE]] = string.insert(
			context[indexes[FUNCTION][LINE]],
			indexes[FUNCTION][COLUMN],
			func_name
		)
	elseif char_1 == "f" then
		local indexes = parser.get_surround_pair(context, cursor_position_relative, char_1, { "_", "." })

		-- Bail out if no surrounding function found.
		if not indexes then
			print("No surrounding function found")
			return
		end

		-- Get the pair to replace with
		local char_2_pairs = utils.get_char_pair(char_2)
		if char_2_pairs == nil then return end

		local space = ""
		local surround_pairs = vim.g.surround_pairs
		if vim.g.surround_space_on_closing_char then
			if table.contains(surround_pairs.nestable, char_2) and char_2 == char_2_pairs[CLOSING] then
				space = " "
			end
		else
			if table.contains(surround_pairs.nestable, char_2) and char_2 == char_2_pairs[OPENING] then
				space = " "
			end
		end

		-- Replace surrounding brackets with char_2 and remove function
		local indexes_func = indexes[FUNCTION]
		indexes = M.surround_delete("(")
		-- get new context after delete()
		context = vim.api.nvim_call_function("getline", { start_line, end_line })

		context[indexes[CLOSING][LINE]] = string.insert(
			context[indexes[CLOSING][LINE]],
			indexes[CLOSING][COLUMN],
			space..char_2_pairs[CLOSING]
		)
		context[indexes[OPENING][LINE]] = string.insert(
			context[indexes[OPENING][LINE]],
			indexes[OPENING][COLUMN],
			char_2_pairs[OPENING]..space
		)
		context[indexes_func[LINE]] = string.remove(
			context[indexes_func[LINE]],
			indexes_func[COLUMN],
			indexes[OPENING][COLUMN]
		)
	elseif char_2 == "f" then
		local indexes = parser.get_surround_pair(context, cursor_position_relative, char_1, {}, n)

		-- Bail out if no surrounding pairs found.
		if not indexes then
			print("No surrounding " .. char_1 .. " found")
			return
		end

		-- Get new funcname
		if not func_name then
			func_name = utils.user_input("funcname: ")
		end
		indexes = M.surround_delete(char_1)
		-- get new context after delete()
		context = vim.api.nvim_call_function("getline", { start_line, end_line })

		context[indexes[CLOSING][LINE]] = string.insert(context[indexes[CLOSING][LINE]], indexes[CLOSING][COLUMN], ")")
		context[indexes[OPENING][LINE]] = string.insert(context[indexes[OPENING][LINE]], indexes[OPENING][COLUMN], "(")
		context[indexes[OPENING][LINE]] = string.insert(
			context[indexes[OPENING][LINE]],
			indexes[OPENING][COLUMN],
			func_name
		)
	else
		-- Get the pair to replace with
		local char_2_pairs = utils.get_char_pair(char_2)
		if char_2_pairs == nil then return end

		local indexes = M.surround_delete(char_1)
		-- Bail out if no surrounding pairs found.
		if not indexes then
			return
		end
		context = vim.api.nvim_call_function("getline", { start_line, end_line })

		local space = ""
		local surround_pairs = vim.g.surround_pairs
		if vim.g.surround_space_on_closing_char then
			if table.contains(surround_pairs.nestable, char_2) and char_2 == char_2_pairs[CLOSING] then
				space = " "
			end
		else
			if table.contains(surround_pairs.nestable, char_2) and char_2 == char_2_pairs[OPENING] then
				space = " "
			end
		end

		context[indexes[CLOSING][LINE]] = string.insert(
			context[indexes[CLOSING][LINE]],
			indexes[CLOSING][COLUMN],
			space..char_2_pairs[CLOSING]
		)
		context[indexes[OPENING][LINE]] = string.insert(
			context[indexes[OPENING][LINE]],
			indexes[OPENING][COLUMN],
			char_2_pairs[OPENING]..space
		)
	end

	-- Replace buffer
	vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, true, context)

	-- Set last_cmd if not a toggle triggered the function
	if not is_toggle then
		vim.g.surround_last_cmd = {
			"surround_replace",
			{ false, vim.NIL, vim.NIL, vim.NIL, vim.NIL, vim.NIL, char_1, char_2, func_name },
		}
		vim.api.nvim_command('silent! call repeat#set("\\<Plug>SurroundRepeat", 1)')
	end
end

function M.toggle_quotes()
	local cursor_position = vim.api.nvim_win_get_cursor(0)
	local start_line, end_line, top_offset, _ = utils.get_line_numbers_by_offset(0)
	local context = vim.api.nvim_call_function("getline", { start_line, end_line })
	local cursor_position_relative = cursor_position
	cursor_position_relative[LINE] = cursor_position[LINE] - top_offset
	cursor_position_relative[COLUMN] = cursor_position[COLUMN] + 1 -- vim indexes columns at 0

	local index
	local _pairs = vim.b.surround_quotes or vim.g.surround_quotes
	for i, pair in ipairs(_pairs) do
		index = parser.get_surround_pair(context, cursor_position_relative, pair)
		if index then
			if i == #_pairs then
				M.surround_replace(
					true,
					start_line,
					end_line,
					top_offset,
					cursor_position_relative,
					context,
					_pairs[#_pairs],
					_pairs[1]
				)
			else
				M.surround_replace(
					true,
					start_line,
					end_line,
					top_offset,
					cursor_position_relative,
					context,
					_pairs[i],
					_pairs[i + 1]
				)
			end
			vim.g.surround_last_cmd = { "toggle_quotes", {} }
			vim.api.nvim_command('silent! call repeat#set("\\<Plug>SurroundRepeat", 1)')
			return
		end
	end
end

function M.toggle_brackets(n)
	n = n or 0
	local cursor_position = vim.api.nvim_win_get_cursor(0)
	local start_line, end_line, top_offset, _ = utils.get_line_numbers_by_offset(vim.g.surround_context_offset)
	local context = vim.api.nvim_call_function("getline", { start_line, end_line })
	local cursor_position_relative = cursor_position
	cursor_position_relative[LINE] = cursor_position[LINE] - top_offset
	cursor_position_relative[COLUMN] = cursor_position[COLUMN] + 1 -- vim indexes columns at 0

	local _pairs = vim.b.surround_brackets or vim.g.surround_brackets
	local indexes = {}
	for i, pair in ipairs(_pairs) do
		indexes[i] = parser.get_surround_pair(context, cursor_position_relative, pair, {}, n)
		if indexes[i] then
			indexes[i] = indexes[i][OPENING]
		else
			indexes[i] = { -1, -1 }
		end
	end

	local index = { -1, -1 }
	for _, opening_indexes in ipairs(indexes) do
		if opening_indexes[LINE] > index[LINE] then
			if opening_indexes[COLUMN] > index[COLUMN] then
				index = opening_indexes
			end
		end
	end

	if index[LINE] < 0 then
		return
	end

	for i, val in ipairs(indexes) do
		if index == val then
			if i == #_pairs then
				M.surround_replace(
					true,
					start_line,
					end_line,
					top_offset,
					cursor_position_relative,
					context,
					_pairs[#_pairs],
					_pairs[1]
				)
			else
				M.surround_replace(
					true,
					start_line,
					end_line,
					top_offset,
					cursor_position_relative,
					context,
					_pairs[i],
					_pairs[i + 1]
				)
			end
			vim.g.surround_last_cmd = { "toggle_brackets", { n } }
			vim.api.nvim_command('silent! call repeat#set("\\<Plug>SurroundRepeat", 1)')
			return
		end
	end
end

function M.repeat_last()
	local cmd = vim.g.surround_last_cmd
	if not cmd then
		print("No previous surround command found.")
		return
	end
	local fun = cmd[1]
	local args = cmd[2]
	for i, arg in pairs(args) do
		if type(arg) == "string" then
			args[i] = utils.quote(string.escape_dquotes(arg))
		else
			args[i] = tostring(arg)
		end
	end
	local str_args = table.concat(args, ",")
	vim.cmd("lua require'surround'." .. fun .. "(" .. utils.get(str_args, "") .. ")")
	vim.api.nvim_command('silent! call repeat#set("\\<Plug>SurroundRepeat", 1)')
end

function M.set_keymaps()
	local function map(mode, key, cmd)
		if string.find(cmd, "<Plug>") then
			-- <Plug> does not work with noremap
			vim.api.nvim_set_keymap(mode, key, cmd, {})
		else
			vim.api.nvim_set_keymap(mode, key, cmd, { noremap = true })
		end
	end

	-- vim will only set '< and '> marks when using gv to re-select last visual selection
	map("v", "<Plug>SurroundAddVisual",        "<esc>gv<cmd>lua require('surround').surround_add(false)<cr>")
	map("n", "<Plug>SurroundAddNormal",        "<cmd>lua require('surround').surround_add(true)<cr>")
	map("n", "<Plug>SurroundDelete",           "<cmd>lua require('surround').surround_delete()<cr>")
	map("n", "<Plug>SurroundReplace",          "<cmd>lua require('surround').surround_replace()<cr>")
	map("n", "<Plug>SurroundRepeat",           "<cmd>lua require('surround').repeat_last()<cr>")
	map("n", "<Plug>SurroundToggleQuotes",     "<cmd>lua require('surround').toggle_quotes()<cr>")
	map("n", "<Plug>SurroundToggleBrackets",   "<cmd>lua require('surround').toggle_brackets()<cr>")

	if not vim.g.surround_load_keymaps then
		return
	end

	if vim.g.surround_mappings_style == "sandwich" then
		map("n", vim.g.surround_prefix .. vim.g.surround_prefix, "<Plug>SurroundRepeat")
		map("x", vim.g.surround_prefix,         "<Plug>SurroundAddVisual")
		map("n", vim.g.surround_prefix .. "a",  "<Plug>SurroundAddNormal")
		map("n", vim.g.surround_prefix .. "d",  "<Plug>SurroundDelete")
		map("n", vim.g.surround_prefix .. "r",  "<Plug>SurroundReplace")
		map("n", vim.g.surround_prefix .. "tq", "<Plug>SurroundToggleQuotes")
		map("n", vim.g.surround_prefix .. "tb", "<Plug>SurroundToggleBrackets")
		map("n", vim.g.surround_prefix .. "tB", "<Plug>SurroundToggleBrackets")
	elseif vim.g.surround_mappings_style == "surround" then
		map("x", "s",  "<Plug>SurroundAddVisual")
		map("n", "ys", "<Plug>SurroundAddNormal")
		map("n", "ds", "<Plug>SurroundDelete")
		map("n", "cs", "<Plug>SurroundReplace")
		map("n", "cq", "<Plug>SurroundToggleQuotes")
	end

	if vim.g.surround_map_insert_mode then
		-- Insert Mode Ctrl-S mappings
		for key, pair in pairs(vim.g.surround_pairs_flat) do
			local left = string.rep("<left>", #pair[CLOSING])

			map("i", "<c-s>" .. key, pair[OPENING] .. pair[CLOSING] .. left)
			map("i", "<c-s>" .. key .. " ", pair[OPENING] .. "  " .. pair[CLOSING] .. left .. "<left>")
			map("i", "<c-s>" .. key .. "<c-s>", pair[OPENING] .. "<cr>" .. pair[CLOSING] .. "<esc>O")

			for side = 1, 2 do
				if #pair[side] == 1 then
					map("i", "<c-s>" .. pair[side], pair[OPENING] .. pair[CLOSING] .. left)
					map("i", "<c-s>" .. pair[side] .. " ", pair[OPENING] .. "  " .. pair[CLOSING] .. left .. "<left>")
					map("i", "<c-s>" .. pair[side] .. "<c-s>", pair[OPENING] .. "<cr>" .. pair[CLOSING] .. "<esc>O")
				end
			end
		end
	end
end

function M.load_autogroups(augroups)
	for group_name, group in pairs(augroups) do
		vim.cmd("augroup " .. group_name)
		vim.cmd("autocmd!")
		for _, cmd in ipairs(group) do
			vim.cmd(table.concat(vim.tbl_flatten({ "autocmd", cmd }), " "))
		end
		vim.cmd("augroup END")
	end
end

function M.setup(opts)
	local function set_default(opt, default)
		if vim.g["surround_" .. opt] ~= nil then
			return
		elseif opts[opt] ~= nil then
			vim.g["surround_" .. opt] = opts[opt]
		else
			vim.g["surround_" .. opt] = default
		end
	end

	local default_pairs = {
		nestable = { b = { "(", ")" }, s = { "[", "]" }, B = { "{", "}" }, a = { "<", ">" } },
		linear = { q = { "'", "'" }, t = { "`", "`" }, d = { '"', '"' } },
	}

	-- instead of letting users completely overwrite the table, add default items to their list
	local user_pairs = (opts.pairs or vim.g.surround_pairs) or {}
	local combined_pairs = {}
	local tmp_keys = {}
	local counter = 1
	for _,option in ipairs({"nestable", "linear"}) do
		user_pairs[option] = user_pairs[option] or {}
		combined_pairs[option] = combined_pairs[option] or {}
		for k,v in pairs(user_pairs[option]) do
			if type(k) == "number" then
				-- to store the table in a vim variable, all entries need a string key
				combined_pairs[option]["!surround_"..counter] = v
				counter = counter + 1
			else
				table.insert(tmp_keys, k)
				combined_pairs[option][k] = v
			end
		end
		for k,v in pairs(default_pairs[option]) do
			if not table.contains(tmp_keys, k) then
				-- do not add duplicate keys to prevent ambiguity and to not overwrite user choices
				table.insert(tmp_keys, k)
				combined_pairs[option][k] = v
			elseif not table.contains(user_pairs, v) then
				-- to store the table in a vim variable, all entries need a string key
				combined_pairs[option]["!surround_"..counter] = v
				counter = counter + 1
			end
		end
	end
	vim.g.surround_pairs = combined_pairs
	vim.g.surround_pairs_flat = table.merge_preserve_keys(combined_pairs.nestable, combined_pairs.linear)


	vim.cmd("function! SurroundNoop(type, ...)\nendfunction")
	set_default("mappings_style", "sandwich")
	set_default("map_insert_mode", true)
	set_default("prefix", "s")
	set_default("prompt", true)
	set_default("load_autogroups", false)
	if vim.g.surround_load_autogroups then
		M.load_autogroups({
			surround_nvim = {
				{
					"FileType",
					"javascript,typescript",
					'let b:surround_quotes = ["\'", \'"\', "`"]',
				},
			},
		})
	end
	set_default("context_offset", 100)
	set_default("space_on_closing_char", false)
	set_default("space_on_alias", false)
	set_default("quotes", { "'", '"' })
	set_default("brackets", { "(", "{", "[" })
	set_default("load_keymaps", true)
	M.set_keymaps()

	-- namespace for highlighting
	if not vim.g.surround_namespace then
		vim.g.surround_namespace = vim.api.nvim_create_namespace("surround")
	end
end

return M
