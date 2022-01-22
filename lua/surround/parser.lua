--- a parser for surrounding character pairs
-- @module parser
local utils = require "surround.utils"

local OPENING = 1
local CLOSING = 2
local LINE = 1
local COLUMN = 2

--- Find index of bracket
-- @param line The content of the current line.
-- @param col_no The column number to look at.
-- @param pair The bracket pair to look for.
-- @param pair_stack The depth of the currently nested brackets.
-- @param requested_pair The level of depth relative to nested pair that should be removed
-- @param opening Boolean value indicating whether to look for the opening bracket. A false value will look for the closing bracket.
-- @return A table containing the values: index_col, space, requested_pair, pair_stack
local function find_bracket_index(line, col_no, pair, pair_stack, requested_pair, opening, no_create_pair_stack)

  local space = false
  local index_col = nil

  local primary
  local opposite
  if opening then
    primary = OPENING
    opposite = CLOSING
  else
    primary = CLOSING
    opposite = OPENING
  end

  -- Get the character currently looping through and the previous one for escaping purposes
  local prev_char = line:sub(col_no - 1, col_no - 1)
  local next_char = line:sub(col_no + #pair[primary], col_no + #pair[primary])

  local curr_char = {}
  curr_char[primary] = line:sub(col_no, col_no + #pair[primary] - 1)
  curr_char[opposite] = line:sub(col_no, col_no + #pair[opposite] - 1)


  -- If found the opposite bracket, add it to the pair stack
  if (curr_char[opposite] == pair[opposite] and prev_char ~= "\\" and not no_create_pair_stack) then
    pair_stack = pair_stack + 1
  end
  if (curr_char[primary] == pair[primary] and prev_char ~= "\\") then
    -- if the pair stack is empty set the indexes
    if pair_stack <= 0 then
      if requested_pair == 0 then
        if primary == OPENING and next_char == " " then
          space = true
        end
        if primary == CLOSING and prev_char == " " then
          space = true
        end
        index_col = col_no
      end
      requested_pair = requested_pair - 1
    end
    pair_stack = pair_stack - 1
  end

  return {
    index_col = index_col,
    space = space,
    requested_pair = requested_pair,
    pair_stack = pair_stack
  }
end

local function get_linear_pair_positions(buffer, cursor_position, surrounding_char)
  local is_finding_opening = true
  local pair = utils.get_char_pair(surrounding_char)

  local opening_index
  local closing_index
  local space_after_opening
  local space_before_closing

  local line_no = cursor_position[LINE]
  local line = buffer[line_no]

  for col_no = 1, #line do
    -- Get the character currently looping through and the previous one for escaping purposes
    local prev_char = line:sub(col_no - 1, col_no - 1)
    local next_char = line:sub(col_no + #pair[OPENING], col_no + #pair[OPENING])

    local curr_char = {}
    curr_char[OPENING] = line:sub(col_no, col_no + #pair[OPENING] - 1)
    curr_char[CLOSING] = line:sub(col_no, col_no + #pair[CLOSING] - 1)

    if (is_finding_opening) then -- if finding the first char do this
      if col_no > cursor_position[COLUMN] then -- Break out if there are no surrounding surround_pairs
        return
      end
      if (curr_char[OPENING] == pair[OPENING] and prev_char ~= "\\") then
        is_finding_opening = false -- found first pair now find last pair
        opening_index = {line_no, col_no}
        space_after_opening = next_char == " "
      end
    else -- if finding the last char then do this
      if (curr_char[CLOSING] == pair[CLOSING] and prev_char ~= "\\") then
        if prev_char == " " then
          space_before_closing = true
        end
        if col_no >= cursor_position[COLUMN] then
          closing_index = {line_no, col_no}
          -- third return value is start of function name; not relevant but here to be consistent with find_nested_pair_positions
          return {opening_index, closing_index, nil, space_after_opening, space_before_closing}
        end
        is_finding_opening = true -- found last pair now find first pair
      end
    end
  end
end

local function get_nested_pair_positions(buffer, cursor_position, surrounding_char, n, func, includes)
  n = n or 0

  local temp_results_table = {}

  local pair = utils.get_char_pair(surrounding_char)

  local opening_index
  local closing_index
  local function_start_index
  local space_after_opening
  local space_before_closing

  -- Find opening character indexes
  -- Initialize pair stack
  temp_results_table["requested_pair"] = n
  temp_results_table["pair_stack"] = 0
  -- Loop through the lines before the cursor in reverse order
  for line_no = cursor_position[LINE], 1, -1 do
    -- Check if already found
    if opening_index then break end
    local line = buffer[line_no]
    if line_no < cursor_position[LINE] then
      -- Loop through the line in reverse order if cursor is not on the line
      for col_no = #line, 1, -1 do
        temp_results_table = find_bracket_index(line, col_no, pair, temp_results_table["pair_stack"], temp_results_table["requested_pair"], true)
        if temp_results_table["index_col"] then
          opening_index = {line_no, temp_results_table["index_col"]}
          space_after_opening = temp_results_table["space"]
          break
        end
      end
    else
      -- Loop through the line in reverse order from the cursor position if cursor is on the line
      for col_no = cursor_position[COLUMN], 1, -1 do
        temp_results_table = find_bracket_index(
          line,
          col_no,
          pair,
          temp_results_table["pair_stack"],
          temp_results_table["requested_pair"],
          true,
          -- cursor could be inside a closing bracket, don't add to the pair_stack in that case
          cursor_position[COLUMN] - col_no < #pair[CLOSING]
        )
        if temp_results_table["index_col"] then
          opening_index = {line_no, temp_results_table["index_col"]}
          space_after_opening = temp_results_table["space"]
          break
        end
      end
    end
  end

  if opening_index == nil then return end

  -- Find closing character indexes
  -- Initialize pair stack
  temp_results_table["requested_pair"] = n
  temp_results_table["pair_stack"] = 0
  -- Loop through the buffer line starting with the line the cursor is on
  for line_no = cursor_position[LINE], #buffer do
    -- If not already found find the closing pair
    if closing_index then break end
    local line = buffer[line_no]
    if line_no > cursor_position[LINE] then
      -- Loop through the characters in the line from the start if cursor is not on the line
      for col_no = 1, #line do
        temp_results_table = find_bracket_index(line, col_no, pair, temp_results_table["pair_stack"], temp_results_table["requested_pair"], false)
        if temp_results_table["index_col"] then
          closing_index = {line_no, temp_results_table["index_col"]}
          space_before_closing = temp_results_table["space"]
          break
        end
      end
    else
      -- Loop through the characters in the line from the cursor position if cursor is on the line
      -- Start earlier to find closing bracket when already *inside* the closing bracket
      local correction = 1 - #pair[CLOSING]
      if opening_index[LINE] == cursor_position[LINE] and opening_index[COLUMN] == cursor_position[COLUMN] then
        correction = 1
      end
      for col_no = cursor_position[COLUMN] + correction, #line do
        temp_results_table = find_bracket_index(
          line,
          col_no,
          pair,
          temp_results_table["pair_stack"],
          temp_results_table["requested_pair"],
          false,
          -- cursor could be inside an opening bracket, don't add to the pair_stack in that case
          col_no - cursor_position[COLUMN] - correction < #pair[OPENING]
        )
        if temp_results_table["index_col"] then
          closing_index = {line_no, temp_results_table["index_col"]}
          space_before_closing = temp_results_table["space"]
          break
        end
      end
    end
  end

  if closing_index == nil then return end

  if func then
    -- Find the start of the function name.
    for col_no = opening_index[COLUMN] - 1, 1, -1 do
      local current_char = buffer[opening_index[LINE]]:sub(col_no, col_no)
      if not string.isalnum(current_char, includes) then
        function_start_index = {opening_index[LINE], col_no + 1}
        break
      end
    end
  end

  return {opening_index, closing_index, function_start_index, space_after_opening, space_before_closing}
end

--- Find the surrounding pair.
-- Returns the indexes of the nearest surrounding pair char in the given buffer relative to the give cursor position.
-- @param buffer the buffer to look for the surrounding pair char
-- @param cur_pos the cursor positon in the buffer (1 indexed)
-- @param char the char for which the surrounding pair must be found
-- @return a table consisting of a pair of indexes (1 indexed) in the form {opening_char_index, closing_char_index} or false if no pairs found
-- @function get_surround_pair
local function get_surround_pair(buffer, cursor_position, surrounding_char,
                                 includes, n)
  local surround_pairs = vim.g.surround_pairs
  local all_pairs = vim.g.surround_pairs_flat
  local special_char = {"f"}
  for _, char in ipairs(special_char) do
    table.insert(all_pairs, #all_pairs + 1, char)
  end
  if not table.contains(all_pairs, surrounding_char) then return nil end

  if (surrounding_char == "f") then
    return get_nested_pair_positions(buffer, cursor_position, "(", n, true, includes)
  end
  -- Check if the character can be nested.
  local is_nestable = false
  for _, pair in pairs(surround_pairs.nestable) do
    if table.contains(pair, surrounding_char) then is_nestable = true end
  end

  if (is_nestable) then
    return get_nested_pair_positions(buffer, cursor_position, surrounding_char, n)
  else
    return get_linear_pair_positions(buffer, cursor_position, surrounding_char)
  end
end

return {get_surround_pair = get_surround_pair}
