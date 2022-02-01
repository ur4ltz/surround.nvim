local function clear_output_buffer()
	vim.api.nvim_call_function("inputsave", {})
	vim.api.nvim_feedkeys(":","nx", true)
	vim.api.nvim_call_function("inputrestore", {})
end

local function log(string, history)
	if vim.g.surround_prompt then
		clear_output_buffer()
		vim.api.nvim_echo({{string, nil}}, history, {})
	end
end

local function get(var, def)
	if var == nil then
		return def
	end
	return var
end

-- table methods

function table.merge(t1, t2)
	local tmp = {}
	for _, v in ipairs(t1) do
		table.insert(tmp, v)
	end
	for _, v in ipairs(t2) do
		table.insert(tmp, v)
	end
	return tmp
end

function table.merge_preserve_keys(t1, t2)
	local tmp = {}
	for k, v in pairs(t1) do
		tmp[k]=v
	end
	for k, v in pairs(t2) do
		tmp[k]=v
	end
	return tmp
end

function table.contains(tbl, string)
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			if table.contains(tbl[k], string) then
				return true
			end
		end
		if v == string then
			return true
		end
	end
	return false
end

function table.slice(tbl, first, last, step)
	local sliced = {}
	for i = first or 1, last or #tbl, step or 1 do
		sliced[#sliced + 1] = tbl[i]
	end
	return sliced
end

-- string functions

local function quote(char)
	if char == '"' then
		return "'" .. char .. "'"
	else
		return '"' .. char .. '"'
	end
end

function string.isalnum(inputstr, includes)
	for i = 1, #inputstr do
		local char = inputstr:sub(i, i)
		if
			not (
				("A" <= char and char <= "Z")
				or ("a" <= char and char <= "z")
				or ("0" <= char and char <= "9")
				or table.contains(get(includes, {}), char)
			)
		then
			return false
		end
	end
	return true
end

function string.escape_dquotes(string)
	local string_esc = ""
	for char in string.gmatch(string, ".") do
		if char == '"' then
			string_esc = string_esc .. "\\" .. char
		else
			string_esc = string_esc .. char
		end
	end
	return string_esc
end

function string.split(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	local element = ""
	for i = 1, #inputstr do
		local current_char = inputstr:sub(i, i)
		if current_char ~= sep then
			element = element .. current_char
		else
			table.insert(t, element)
			element = ""
		end
	end
	if #element > 0 then
		table.insert(t, element)
	end
	return t
end

function string.insert(inputstr, index, sub_str)
	return inputstr:sub(1, index - 1) .. sub_str .. inputstr:sub(index, #inputstr + 1)
end

function string.remove(inputstr, from, to)
	if to == nil then
		to = from + 1
	end
	return inputstr:sub(1, from - 1) .. inputstr:sub(to, #inputstr)
end

function string.set(inputstr, index, sub_str)
	return inputstr:sub(1, index - 1) .. sub_str .. inputstr:sub(index + 1, #inputstr)
end

local function get_visual_pos()
	local start = vim.api.nvim_buf_get_mark(0, "<")
	local start_line = start[1]
	local start_col = start[2] + 1

	local _end = vim.api.nvim_buf_get_mark(0, ">")
	local end_line = _end[1]
	local end_l = vim.fn.getline(end_line)
	local end_col = vim.str_byteindex(
		end_l,
		-- Use `math.min()` because it might lead to 'index out of range' error
		-- when mark is positioned at the end of line (that extra space which is
		-- selected when selecting with `v$`)
		vim.str_utfindex(end_l, math.min(#end_l, _end[2] + 1))
	)
	return start_line, start_col, end_line, end_col
end

local function get_operator_pos()
	local start = vim.api.nvim_buf_get_mark(0, "[")
	local start_line = start[1]
	local start_col = start[2] + 1
	local _end = vim.api.nvim_buf_get_mark(0, "]")
	local end_line = _end[1]
	local end_col = _end[2] + 2
	return start_line, start_col, end_line, end_col
end

local function tprint(tbl, indent)
	if not indent then
		indent = 0
	end
	for k, v in pairs(tbl) do
		local formatting = string.rep("  ", indent) .. k .. ": "
		if type(v) == "table" then
			print(formatting)
			tprint(v, indent + 1)
		elseif type(v) == "boolean" then
			print(formatting .. tostring(v))
		else
			print(formatting .. v)
		end
	end
end

local function user_input(message)
	vim.api.nvim_call_function("inputsave", {})
	local val = vim.api.nvim_call_function("input", { message })
	vim.api.nvim_call_function("inputrestore", {})
	return val
end

local load_keymaps = function(keymap_table)
	for _, keymap in ipairs(keymap_table) do
		vim.api.nvim_set_keymap(unpack(keymap))
	end
end

local function get_nth_element(tbls, n)
	local elements = {}
	for _, tbl in ipairs(tbls) do
		table.insert(elements, tbl[n])
	end
	return elements
end

local function get_line_numbers_by_offset(offset)
	local current_cursor_position = vim.api.nvim_win_get_cursor(0)
	local current_line_number = current_cursor_position[1]
	local total_lines = vim.fn.line("$")
	local top_offset, bottom_offset

	if current_line_number > offset then -- If there are more than offset lines above the current line.
		top_offset = current_line_number - offset - 1
	else
		top_offset = 0
	end

	if total_lines - current_line_number > offset then -- if there are more than offset lines below the current line.
		bottom_offset = total_lines - (current_line_number + offset)
	else
		bottom_offset = 0
	end
	return 1 + top_offset, total_lines - bottom_offset, top_offset, bottom_offset
end

local function table_keys(t)
	local keys = {}
	for k, _ in pairs(t) do
		table.insert(keys, k)
	end
	return keys
end

local function has_value(tab, val)
	for index, value in ipairs(tab) do
		if value == val then
			return true
		end
	end

	return false
end

local function get_char()
	local char_raw = vim.fn.getchar()
	if type(char_raw) == "number" then
		return char_raw, vim.fn.nr2char(char_raw)
	else
		-- special characters like <BS> or <S-Left> are already returned as strings
		return char_raw, char_raw
	end
end

local function get_surround_chars(surrounding)
	if not surrounding then
		log("(Surround) Character: ", false)
		local char_nr
		char_nr, surrounding = get_char()

		-- 27 is <ESC>
		if char_nr == 27 then
			log("(Surround) Character: ❌", true)
			return
		end

		log("(Surround) Character: " .. string.escape_dquotes(surrounding), true)
	end

	for i,v in pairs(vim.g.surround_pairs_flat) do
		if surrounding == i then
			local sa = vim.g.surround_space_on_alias
			local sc = vim.g.surround_space_on_closing_char
			if sa then
				surrounding = (sc and v[2]) or v[1]
			else
				surrounding = (sc and v[1]) or v[2]
			end
			break
		end
	end

	return surrounding
end

local function get_char_pair(char)
	for _, pair in pairs(vim.g.surround_pairs_flat) do
		if table.contains(pair, char) then
			return pair
		end
	end
end

local function map(table, func)
	local t = {}
	for k,v in pairs(table) do
		if type(v) == "table" then
			t[k] = map(table[k], func)
		else
			t[k] = func(v)
		end
	end
	return t
end

local MOTIONS_RAW = {
	final = {
		left_right = {
			left = {"h", "<Left>", "<C-H>", "<BS>", "^", "<Home>"},
			right = {"l", "<Right>", "<SPACE>", "$", "<END>"},
			other = {";", ",", "|"}
		},
		up_down = {
			up = {"k", "<Up>", "<C-P>", "-"},
			down = {"j", "<Down>", "<C-J>", "<NL>", "<C-N>", "+", "<C-M>", "<CR>", "_"},
			other = {"G", "<C-END>", "<C-Home>", "%"}
		},
		words = {"<S-Right>", "w", "<C-Right>", "W", "e", "E", "<S-Left>", "b", "<C-Left>", "B"},
		objects = {"(", ")", "{", "}"},
	},
	incomplete = {"a", "i", "g", "[", "]", "f", "F", "t", "T"},
	selection_prefix = {"w", "W", "s", "p", "[", "]", "(", ")", "b", "<", ">", "t", "{", "}", "B", '"', "'", "`"},
	g_prefix = {"_", "0", "<Home>", "m", "M", "$", "<End>", "g", "k", "<Up>", "j", "<Down>", "e", "E"},
	bracket_prefix = {"[", "]"},
}

local MOTIONS_ESC = map(MOTIONS_RAW, function(item) return vim.api.nvim_replace_termcodes(item, true, false, true) end)

local function omaps()
	local ret = {}
	local global_omaps = vim.api.nvim_get_keymap("o")
	local buffer_omaps = vim.api.nvim_buf_get_keymap(0, "o")
	local o_maps = table.merge(global_omaps, buffer_omaps)
	for _,v in ipairs(o_maps) do
		-- <Plug> is a not a producable character, only used for internal mappings
		if not string.find(v.lhs, "<Plug>") then
			table.insert(ret, v.lhs)
		end
	end
	return ret
end


local function get_motion()
	local motion = ""
	local motion_esc = ""
	local count = ""
	local msg = ""
	local last_char = ""
	local count_complete = false
	local o_maps = omaps()
	while true do
		log("(Surround) Motion: " .. msg, false)
		local char_raw, char_string = get_char()

		-- 27 is <ESC>
		if char_raw == 27 then return nil end

		if count .. motion == "" and char_string == "0" then
			-- "0" motion (beginning of line) does not take a count
			return "0"
		end

		if "0" <= char_string and char_string <= "9" and not count_complete then
			count = count .. char_string
			msg = msg .. char_string
		else
			count_complete = true
			motion = motion .. char_string

			-- escape non-alphanumeric characters
			if not string.isalnum(char_string) then
				msg = msg .. "\\" .. char_string
				motion_esc = motion_esc .. "%" .. char_string
			else
				msg = msg .. char_string
				motion_esc = motion_esc .. char_string
			end

			local custom_omap = false
			for _,v in ipairs(o_maps) do
				local idx,_ = string.find(v, motion_esc)
				if idx == 1 then
					custom_omap = true
					if #v == #motion then
						break
					end
				end
			end

			if
				   (has_value({"a", "i"}, last_char) and table.contains(MOTIONS_ESC["selection_prefix"], char_string))
				or (has_value({"[", "]"}, last_char) and table.contains(MOTIONS_ESC["bracket_prefix"], char_string))
				or (has_value({"f", "F", "t", "T"}, last_char) and type(char_raw) == "number")
				or (last_char == "g" and table.contains(MOTIONS_ESC["g_prefix"], char_string))
				or (table.contains(MOTIONS_ESC["final"], char_string) and not table.contains(MOTIONS_ESC["incomplete"], last_char))
			then
				break
			elseif
				not ((table.contains(MOTIONS_ESC["incomplete"], char_string)
				and not table.contains(MOTIONS_ESC["incomplete"], last_char))
				or custom_omap)
			then
				log("(Surround) Motion: " .. msg .. " ❌ (invalid)", true)
				return nil
			end
		end
		last_char = char_string
	end
	log("(Surround) Motion: " .. msg .. " ✅", true)
	return count..motion
end

local function highlight_motion_selection()
	-- this function assumes that '[ and '] were manually set before
	local beg_mark = vim.api.nvim_buf_get_mark(0, "[")
	local end_mark = vim.api.nvim_buf_get_mark(0, "]")
	local ext_mark = vim.api.nvim_buf_set_extmark(
		0,
		vim.g.surround_namespace,
		beg_mark[1] - 1,
		beg_mark[2],
		{
			end_line = end_mark[1] - 1,
			end_col = end_mark[2] + 1,
			hl_group = "Visual",
			priority = 1000
		}
	)
	-- force a redraw of the window to show highlight immediately
	vim.api.nvim_command(":redraw")
	return ext_mark
end

return {
	clear_output_buffer = clear_output_buffer,
	log = log,
	tprint = tprint,
	has_value = has_value,
	user_input = user_input,
	get_line_numbers_by_offset = get_line_numbers_by_offset,
	table_keys = table_keys,
	get_nth_element = get_nth_element,
	get_visual_pos = get_visual_pos,
	get_operator_pos = get_operator_pos,
	get_motion = get_motion,
	get_char_pair = get_char_pair,
	get_surround_chars = get_surround_chars,
	get_char = get_char,
	load_keymaps = load_keymaps,
	quote = quote,
	get = get,
	map = map,
	omaps = omaps,
	highlight_motion_selection = highlight_motion_selection,
}
